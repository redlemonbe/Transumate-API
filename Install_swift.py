try:
    import requests
except ImportError:
    raise RuntimeError("The 'requests' module is not installed. Please run 'pip install requests'")
    
import os
import subprocess
import sys
import requests

# Répertoire cible pour les modèles
MODEL_DIR = os.path.expanduser("~/.transumate/models")
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

# Liste des packages à installer
PIP_PACKAGES = [
    "requests==2.32.3",
    "tqdm==4.66.5",
    "transformers==4.45.2",
    "torch==2.5.1",
    "torchaudio==2.5.1",
    "torchvision==0.20.1",
    # Ajoutez d'autres packages nécessaires ici...
]


def ensure_pip_installed():
    """
    Vérifie si pip est disponible. Si non, l'installe automatiquement.
    """
    try:
        subprocess.check_call([sys.executable, "-m", "ensurepip", "--upgrade"])
        subprocess.check_call([sys.executable, "-m", "pip", "install", "--upgrade", "pip"])
        print("INFO: pip is installed and updated.")
    except Exception as e:
        raise RuntimeError(f"ERROR: Unable to install pip. {e}")


def install_pip_packages():
    """
    Installe les packages spécifiés dans la liste PIP_PACKAGES.
    Ajoute un indicateur de progression.
    """
    total = len(PIP_PACKAGES)
    for i, package in enumerate(PIP_PACKAGES, start=1):
        print(f"PROGRESS: Installing package {i}/{total} - {package}")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", package])
            print(f"INFO: Installed {package}")
        except subprocess.CalledProcessError as e:
            print(f"ERROR: Failed to install {package}: {e}")


def download_file(url, dest_path):
    """
    Télécharge un fichier depuis une URL et le sauvegarde à un emplacement donné.
    Émet des messages de progression.
    """
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        total_size = int(response.headers.get('content-length', 0))
        with open(dest_path, "wb") as f:
            downloaded_size = 0
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    downloaded_size += len(chunk)
                    progress = int(100 * downloaded_size / total_size)
                    print(f"PROGRESS: Downloading {os.path.basename(dest_path)} - {progress}%")
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
    Télécharge les modèles et installe les packages.
    """
    try:
        # Étape 1 : Vérifier et installer pip
        print("INFO: Vérification de pip...")
        ensure_pip_installed()

        # Étape 2 : Installation des packages pip
        print("INFO: Installation des packages pip...")
        install_pip_packages()

        # Étape 3 : Téléchargement des modèles
        print("INFO: Téléchargement des modèles...")
        os.makedirs(MODEL_DIR, exist_ok=True)
        total_models = len(MODEL_FILES)
        for i, (model_name, files) in enumerate(MODEL_FILES.items(), start=1):
            print(f"PROGRESS: Downloading model {i}/{total_models} - {model_name}")
            try:
                download_model_files(model_name, files)
            except Exception as e:
                print(f"ERROR: Échec du téléchargement pour {model_name}: {e}")

        print("INFO: Configuration complète.")

    except Exception as e:
        print(f"ERROR: Une erreur est survenue. {e}")


if __name__ == "__main__":
    main()
