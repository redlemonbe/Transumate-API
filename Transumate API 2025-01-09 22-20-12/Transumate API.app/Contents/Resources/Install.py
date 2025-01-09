#!/bin/bash

# Vérification des prérequis
echo "Mise à jour des paquets..."
brew update

echo "Installation de Python et des dépendances..."
brew install python3
pip3 install --upgrade pip

echo "Installation des dépendances nécessaires..."
pip3 install torch transformers sentencepiece

# Téléchargement du modèle
echo "Téléchargement du modèle jbochi/madlad400-3b-mt au format GGUF..."
mkdir -p ~/gguf_model
cd ~/gguf_model
curl -L -o madlad400-3b-mt.gguf https://huggingface.co/jbochi/madlad400-3b-mt/resolve/main/madlad400-3b-mt.gguf

echo "Installation terminée."