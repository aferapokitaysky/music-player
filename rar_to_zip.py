#!/usr/bin/env python3
import os
import sys
import zipfile
import subprocess
import tempfile
import shutil

def extract_rar(rar_path, extract_dir):
    # 1. Попытка использовать 'unar' (самый популярный CLI архиватор на macOS)
    if shutil.which("unar"):
        print("[*] Найдена утилита 'unar', распаковка...")
        result = subprocess.run(["unar", "-o", extract_dir, rar_path], capture_output=True, text=True)
        if result.returncode == 0:
            return True
        print("[-] Ошибка 'unar':", result.stderr)

    # 2. Попытка использовать стандартный 'unrar'
    if shutil.which("unrar"):
        print("[*] Найдена утилита 'unrar', распаковка...")
        result = subprocess.run(["unrar", "x", rar_path, extract_dir], capture_output=True, text=True)
        if result.returncode == 0:
            return True
        print("[-] Ошибка 'unrar':", result.stderr)

    # 3. Попытка использовать библиотеку python 'rarfile'
    try:
        import rarfile
        print("[*] Использование библиотеки python 'rarfile'...")
        with rarfile.RarFile(rar_path) as rf:
            rf.extractall(extract_dir)
        return True
    except ImportError:
        print("[-] Библиотека python 'rarfile' не установлена.")
    except Exception as e:
        print("[-] Ошибка 'rarfile':", e)

    # Если ничего не помогло, даем понятную инструкцию
    print("\n[!] Ошибка: На macOS не найден инструмент для распаковки RAR.")
    print("Чтобы скрипт работал, выполните в терминале ОДНУ из команд:")
    print("  brew install unar")
    print("или:")
    print("  pip3 install rarfile")
    return False

def make_zip(source_dir, zip_path):
    print(f"[*] Создание ZIP архива: {zip_path}...")
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(source_dir):
            for file in files:
                file_path = os.path.join(root, file)
                rel_path = os.path.relpath(file_path, source_dir)
                zipf.write(file_path, rel_path)
    print("[+] ZIP архив успешно создан!")

def convert_rar_to_zip(rar_path):
    if not os.path.exists(rar_path):
        print(f"[!] Ошибка: Файл не найден: '{rar_path}'")
        return
    
    if not rar_path.lower().endswith('.rar'):
        print(f"[!] Ошибка: Файл '{rar_path}' не является .rar архивом")
        return

    rar_abs = os.path.abspath(rar_path)
    base_dir = os.path.dirname(rar_abs)
    base_name = os.path.splitext(os.path.basename(rar_abs))[0]
    zip_path = os.path.join(base_dir, base_name + ".zip")

    # Временная папка для распаковки
    temp_dir = tempfile.mkdtemp()
    try:
        print(f"[*] Начинаем конвертацию '{rar_path}'...")
        if extract_rar(rar_abs, temp_dir):
            make_zip(temp_dir, zip_path)
    finally:
        # Очистка временных файлов
        shutil.rmtree(temp_dir)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        # Если аргументов нет, ищем все .rar файлы в текущей папке
        rar_files = [f for f in os.listdir('.') if f.lower().endswith('.rar')]
        if not rar_files:
            print("Использование:")
            print("  python3 rar_to_zip.py <путь_к_rar_файлу>")
            print("\nИли просто положите этот скрипт в папку с .rar файлами и запустите без аргументов.")
            sys.exit(1)
        
        print(f"[*] Найдено .rar файлов в текущей папке: {len(rar_files)}")
        for f in rar_files:
            convert_rar_to_zip(f)
            print("-" * 50)
    else:
        convert_rar_to_zip(sys.argv[1])
