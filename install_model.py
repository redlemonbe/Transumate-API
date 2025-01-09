import os
import requests

# Répertoire cible pour les modèles
MODEL_DIR = os.path.expanduser("~/.models")
MODEL_FILES = {
    "Helsinki-NLP/opus-mt-mul-en": [
        "config.json",
        "pytorch_model.bin",
        "tokenizer_config.json",
        "source.spm",
        "target.spm",
        "vocab.json",
    ],
    "facebook/bart-large-cnn": [
        "config.json",
        "model.safetensors",
        "generation_config.json",
        "vocab.json",
        "merges.txt",
        "tokenizer.json",
    ],
}

BASE_URL = "https://huggingface.co"

def download_file(url, dest_path):
    """
    Télécharge un fichier depuis une URL et le sauvegarde à un emplacement donné.
    """
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        with open(dest_path, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        print(f"INFO: Téléchargé {url} -> {dest_path}")
    except Exception as e:
        raise RuntimeError(f"Erreur lors du téléchargement de {url}: {e}")

def download_model_files(model_name, files):
    """
    Télécharge les fichiers nécessaires pour un modèle spécifique.
    """
    model_path = os.path.join(MODEL_DIR, model_name.replace("/", "__"))
    os.makedirs(model_path, exist_ok=True)

    for file_name in files:
        file_url = f"{BASE_URL}/{model_name}/resolve/main/{file_name}"
        file_path = os.path.join(model_path, file_name)
        if not os.path.exists(file_path):
            print(f"INFO: Téléchargement de {file_name} pour {model_name}...")
            download_file(file_url, file_path)
        else:
            print(f"INFO: {file_name} existe déjà, pas de téléchargement.")

def main():
    """
    Télécharge les modèles spécifiés dans MODEL_FILES.
    """
    os.makedirs(MODEL_DIR, exist_ok=True)
    for model_name, files in MODEL_FILES.items():
        print(f"INFO: Téléchargement des fichiers pour le modèle {model_name}...")
        try:
            download_model_files(model_name, files)
        except Exception as e:
            print(f"ERREUR: Échec du téléchargement pour {model_name}: {e}")

if __name__ == "__main__":
    main()