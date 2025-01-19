import os
import re
import json
import sys
import torch.multiprocessing as mp
from goose3 import Goose
from langdetect import detect, DetectorFactory
from transformers import MarianMTModel, MarianTokenizer, AutoTokenizer, AutoModelForSeq2SeqLM
from keybert import KeyBERT
from googletrans import Translator

# Neutralize torch.distributed and other missing modules
try:
    import torch.distributed
except ImportError:
    sys.modules["torch.distributed"] = None

try:
    import torch.testing
except ImportError:
    sys.modules["torch.testing"] = None

# Neutralize _pocketfft and other numpy-related errors
try:
    import numpy.fft._pocketfft
except ImportError:
    sys.modules["numpy.fft._pocketfft"] = None

# Neutralize other scipy-specific errors
try:
    import scipy.sparse
    import scipy._lib._array_api
except ImportError:
    pass  # Ignore if absent

# Disable warnings and configure the environment
os.environ["TOKENIZERS_PARALLELISM"] = "false"
os.environ["TORCH_INDUCTOR"] = "0"
os.environ["TORCH_COMPILE"] = "0"
os.environ["TORCH_CPP_LOG_LEVEL"] = "ERROR"
os.environ["PYTORCH_DISABLE_DISTRIBUTED"] = "1"

# Model directory
MODEL_DIR = os.path.expanduser("~/.models")
TRANSLATION_MODEL_NAME = "Helsinki-NLP/opus-mt-mul-en"
SUMMARIZATION_MODEL_NAME = "facebook/bart-large-cnn"

# Ensure reproducibility of language detection
DetectorFactory.seed = 0

# Initialize Google Translator
translator = Translator()

# Load models before execution
def load_models():
    try:
        translation_model_path = os.path.join(MODEL_DIR, TRANSLATION_MODEL_NAME.replace("/", "__"))
        translation_model = MarianMTModel.from_pretrained(translation_model_path)
        translation_tokenizer = MarianTokenizer.from_pretrained(translation_model_path)

        summarization_model_path = os.path.join(MODEL_DIR, SUMMARIZATION_MODEL_NAME.replace("/", "__"))
        summarization_model = AutoModelForSeq2SeqLM.from_pretrained(summarization_model_path)
        summarizer_tokenizer = AutoTokenizer.from_pretrained(summarization_model_path)

        return translation_model, translation_tokenizer, summarization_model, summarizer_tokenizer
    except Exception as e:
        print(json.dumps({"status": "error", "error": f"Model loading failed: {e}"}))
        sys.exit(1)

# Extract article with Goose3
def extract_with_goose(url):
    g = Goose()
    article = g.extract(url=url)
    return (
        article.title or "not_found",
        article.authors[0] if article.authors else "not_found",
        article.publish_date or "not_found",
        article.cleaned_text or "not_found",
        article.meta_keywords or []  # Extract keywords from Goose
    )

# Translate text using MarianMTModel
def translate_text(text, tokenizer, model):
    sentences = re.split(r'(?<=[.!?]) +', text)
    translated_chunks = []
    for sentence in sentences:
        inputs = tokenizer([sentence], return_tensors="pt", truncation=True)
        outputs = model.generate(inputs["input_ids"], num_beams=4, early_stopping=True)
        translated_chunks.append(tokenizer.decode(outputs[0], skip_special_tokens=True))
    return " ".join(translated_chunks)

# Translate title using Google Translator
def translate_title(title, src_lang):
    try:
        translated = translator.translate(title, src=src_lang, dest='en')
        return translated.text
    except Exception as e:
        print(f"Google Translate error: {e}")
        return title

# Summarize text using BART model
def summarize_text(text, tokenizer, model):
    inputs = tokenizer([text], return_tensors="pt", truncation=True, max_length=1024)
    summary_ids = model.generate(
        inputs["input_ids"], max_length=600, min_length=300, num_beams=4, early_stopping=True
    )
    return tokenizer.decode(summary_ids[0], skip_special_tokens=True)

# Extract keywords using KeyBERT
def extract_keywords(text, goose_keywords):
    kw_model = KeyBERT()
    keywords = [kw[0] for kw in kw_model.extract_keywords(text, top_n=5, stop_words="english")]
    combined_keywords = list(set(goose_keywords + keywords))  # Combine and ensure uniqueness
    return combined_keywords[:5]  # Return top 5 unique keywords

# Clean text
def clean_text(text):
    return text.replace('\\"', '').replace("\\'", '').replace('"', '').replace("'", '').strip()

# Main processing function
def process_url(url, translation_model, translation_tokenizer, summarization_model, summarizer_tokenizer):
    try:
        title, author, date, content, goose_keywords = extract_with_goose(url)
        if content == "not_found":
            return {"status": "error", "error": "Main content not found."}

        lang = detect(content)
        translated_title = title
        if lang != "en":
            translated_title = translate_title(translated_title, lang)
            content = translate_text(content, translation_tokenizer, translation_model)

            # Ensure the translated title is not empty or incorrect
            if not translated_title or translated_title == title:
                translated_title = "Translation not available."

        summary = clean_text(summarize_text(content, summarizer_tokenizer, summarization_model))

        keywords = extract_keywords(content, goose_keywords)

        return {
            "status": "ok",
            "title": title,
            "translated_title": translated_title,
            "author": author,
            "date": date,
            "keywords": {f"keyword_{i + 1}": kw for i, kw in enumerate(keywords)},
            "text": summary,
        }
    except Exception as e:
        return {"status": "error", "error": str(e)}

# Redirect outputs to /dev/null
class SuppressOutput:
    def __enter__(self):
        self.stdout = sys.stdout
        self.stderr = sys.stderr
        sys.stdout = open(os.devnull, 'w')
        sys.stderr = open(os.devnull, 'w')

    def __exit__(self, exc_type, exc_value, traceback):
        sys.stdout.close()
        sys.stderr.close()
        sys.stdout = self.stdout
        sys.stderr = self.stderr

# Main function
def main():
    if len(sys.argv) != 2:
        print(json.dumps({"status": "error", "error": "Usage: python extract_v5.py <URL>"}))
        return

    url = sys.argv[1]
    translation_model, translation_tokenizer, summarization_model, summarizer_tokenizer = load_models()

    with SuppressOutput():
        result = process_url(url, translation_model, translation_tokenizer, summarization_model, summarizer_tokenizer)
    print(json.dumps(result, indent=4, ensure_ascii=False))

if __name__ == "__main__":
    mp.set_start_method('spawn')  # Enable multi-CPU support
    main()
