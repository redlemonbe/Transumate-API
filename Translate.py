import os
import re
import json
import sys
from goose3 import Goose
from langdetect import detect, DetectorFactory
from transformers import (
    MarianMTModel,
    MarianTokenizer,
    AutoTokenizer,
    AutoModelForSeq2SeqLM,
)
from keybert import KeyBERT

# Neutraliser torch.distributed et d'autres modules manquants
try:
    import torch.distributed
except ImportError:
    sys.modules["torch.distributed"] = None

try:
    import torch.testing
except ImportError:
    sys.modules["torch.testing"] = None

# Neutraliser _pocketfft et autres erreurs liées à numpy
try:
    import numpy.fft._pocketfft
except ImportError:
    sys.modules["numpy.fft._pocketfft"] = None

# Neutraliser d'autres erreurs spécifiques à scipy
try:
    import scipy.sparse
    import scipy._lib._array_api
except ImportError:
    pass  # Ignorez si absent

# Désactiver les warnings et configurer l'environnement
os.environ["TOKENIZERS_PARALLELISM"] = "false"
os.environ["TORCH_INDUCTOR"] = "0"
os.environ["TORCH_COMPILE"] = "0"
os.environ["TORCH_CPP_LOG_LEVEL"] = "ERROR"
os.environ["PYTORCH_DISABLE_DISTRIBUTED"] = "1"

# Répertoire des modèles
MODEL_DIR = os.path.expanduser("~/.models")
TRANSLATION_MODEL_NAME = "Helsinki-NLP/opus-mt-mul-en"
SUMMARIZATION_MODEL_NAME = "facebook/bart-large-cnn"

# Assurer la reproductibilité de la détection de langue
DetectorFactory.seed = 0

# Chargement des modèles avant exécution
try:
    translation_model_path = os.path.join(MODEL_DIR, TRANSLATION_MODEL_NAME.replace("/", "__"))
    translation_model = MarianMTModel.from_pretrained(translation_model_path)
    translation_tokenizer = MarianTokenizer.from_pretrained(translation_model_path)

    summarization_model_path = os.path.join(MODEL_DIR, SUMMARIZATION_MODEL_NAME.replace("/", "__"))
    summarization_model = AutoModelForSeq2SeqLM.from_pretrained(summarization_model_path)
    summarizer_tokenizer = AutoTokenizer.from_pretrained(summarization_model_path)
except Exception as e:
    print(json.dumps({"status": "error", "error": f"Model loading failed: {e}"}))
    sys.exit(1)

# Extraction d'article avec Goose3
def extract_with_goose(url):
    g = Goose()
    article = g.extract(url=url)
    return (
        article.title or "not_found",
        article.authors[0] if article.authors else "not_found",
        article.publish_date or "not_found",
        article.cleaned_text or "not_found",
    )

# Traduction du texte
def translate_text(text):
    sentences = re.split(r'(?<=[.!?]) +', text)
    translated_chunks = []
    for sentence in sentences:
        inputs = translation_tokenizer([sentence], return_tensors="pt", truncation=True)
        outputs = translation_model.generate(inputs["input_ids"], num_beams=4, early_stopping=True)
        translated_chunks.append(translation_tokenizer.decode(outputs[0], skip_special_tokens=True))
    return " ".join(translated_chunks)

# Résumé du texte
def summarize_text(text):
    inputs = summarizer_tokenizer([text], return_tensors="pt", truncation=True, max_length=1024)
    summary_ids = summarization_model.generate(
        inputs["input_ids"], max_length=400, min_length=150, num_beams=4, early_stopping=True
    )
    return summarizer_tokenizer.decode(summary_ids[0], skip_special_tokens=True)

# Extraction des mots-clés
def extract_keywords(text):
    kw_model = KeyBERT()
    return [kw[0] for kw in kw_model.extract_keywords(text, top_n=5, stop_words="english")]

# Nettoyage du texte
def clean_text(text):
    return text.replace('\\"', '').replace("\\'", '').replace('"', '').replace("'", '').strip()

# Traitement principal
def process_url(url):
    try:
        title, author, date, content = extract_with_goose(url)
        if content == "not_found":
            return {"status": "error", "error": "Contenu principal introuvable."}

        lang = detect(content)
        translated_title = title
        if lang != "en":
            content = translate_text(content)
            translated_title = translate_text(title)

        summary = clean_text(summarize_text(content))
        keywords = extract_keywords(content)

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

# Redirection des sorties vers /dev/null
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

# Fonction principale
def main():
    if len(sys.argv) != 2:
        print(json.dumps({"status": "error", "error": "Usage: python extract_v5.py <URL>"}))
        return

    url = sys.argv[1]
    with SuppressOutput():
        result = process_url(url)
    print(json.dumps(result, indent=4, ensure_ascii=False))

if __name__ == "__main__":
    main()
