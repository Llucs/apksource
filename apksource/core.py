import os
import re
import subprocess
import shutil
import sys # <--- Adicionar importação de sys
from rich.console import Console
from rich.progress import track
from rich.text import Text

console = Console()

MIN_APKTOOL_VERSION = "2.7.0"
MIN_JADX_VERSION = "1.4.7"
MIN_JAVA_VERSION = "17"

class ApkSourceError(Exception):
    """Exceção base para erros do ApkSource."""
    pass

def log_info(message):
    """Exibe uma mensagem informativa."""
    console.print(f"[bold cyan]INFO[/bold cyan] {message}")

def log_error(message):
    """Exibe uma mensagem de erro e encerra o programa."""
    print(f"[bold red]ERRO[/bold red] {message}", file=sys.stderr)
    raise ApkSourceError(message)

def get_version(command, regex):
    """Executa um comando e extrai a versão usando regex."""
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=True,
            shell=True,
            timeout=10
        )
        match = re.search(regex, result.stdout + result.stderr)
        if match:
            return match.group(1)
        return None
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
        return None

def compare_versions(v1, v2):
    """Compara duas strings de versão (v1 >= v2)."""
    def normalize(v):
        return [int(x) for x in re.sub(r'(\.0+)*$', '', v).split(".")]
    return normalize(v1) >= normalize(v2)

def check_dependency(cmd, min_version, version_cmd, version_regex):
    """Verifica se uma dependência está instalada e atende à versão mínima."""
    log_info(f"Verificando dependência: [bold yellow]{cmd}[/bold yellow] (Mín: {min_version})...")

    if not shutil.which(cmd):
        log_error(f"Comando [bold red]{cmd}[/bold red] não encontrado. Por favor, instale-o e certifique-se de que está no PATH.")

    current_version = get_version(version_cmd, version_regex)

    if not current_version:
        log_error(f"Não foi possível determinar a versão de [bold red]{cmd}[/bold red].")

    log_info(f"Versão atual de [bold yellow]{cmd}[/bold yellow]: {current_version}")

    if compare_versions(current_version, min_version):
        log_info(f"[bold green]{cmd}[/bold green] versão OK.")
    else:
        log_error(f"Versão de [bold red]{cmd}[/bold red] ([yellow]{current_version}[/yellow]) é inferior à mínima requerida ([yellow]{min_version}[/yellow]). Por favor, atualize.")

def check_all_dependencies():
    """Verifica todas as dependências necessárias."""
    check_dependency(
        "java",
        MIN_JAVA_VERSION,
        "java -version",
        r'version\s+"(\d+)\.'
    )
    check_dependency(
        "apktool",
        MIN_APKTOOL_VERSION,
        "apktool --version",
        r'(\d+\.\d+\.\d+)'
    )
    check_dependency(
        "jadx",
        MIN_JADX_VERSION,
        "jadx --version",
        r'jadx\s+version\s+(\d+\.\d+\.\d+)'
    )

def smart_project_name(apk_path):
    """Gera um nome de projeto inteligente a partir do caminho do APK."""
    base_name = os.path.basename(apk_path)
    name_without_ext = os.path.splitext(base_name)[0]
    # Remove caracteres inválidos e substitui espaços por underscore
    project_name = re.sub(r'[^a-zA-Z0-9_]', '', name_without_ext.replace(' ', '_'))
    return project_name if project_name else "ApkProject"

def run_decompile_command(command, description):
    """Executa um comando de descompilação e lida com erros."""
    log_info(f"Iniciando: {description}...")
    try:
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            shell=True
        )

        # Exibir a saída em tempo real (opcional, mas útil para feedback)
        # for line in iter(process.stdout.readline, ''):
        #     console.print(f"[dim]{line.strip()}[/dim]")

        stdout, stderr = process.communicate()

        if process.returncode != 0:
            log_error(f"{description} falhou. Código de saída: {process.returncode}\n[dim]Saída de erro:\n{stderr}[/dim]")
        
        log_info(f"[bold green]{description} concluída com sucesso.[/bold green]")
        return True

    except FileNotFoundError:
        log_error(f"Comando não encontrado. Certifique-se de que {command.split()[0]} está instalado e no PATH.")
    except Exception as e:
        log_error(f"Erro inesperado durante {description}: {e}")

def setup_gradle_project(project_name):
    """Gera os arquivos de configuração Gradle (build.gradle, settings.gradle, etc.)."""
    log_info("Configurando projeto Gradle...")
    
    # 1. Root build.gradle
    root_build_gradle_content = f"""// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {{
    id 'com.android.application' version '8.2.0' apply false
    id 'com.android.library' version '8.2.0' apply false
    id 'org.jetbrains.kotlin.android' version '1.9.0' apply false
    id 'com.google.dagger.hilt.android' version '2.48' apply false
}}

task clean(type: Delete) {{
    delete rootProject.buildDir
}}
"""
    with open(os.path.join(project_name, "build.gradle"), "w") as f:
        f.write(root_build_gradle_content)

    # 2. settings.gradle
    with open(os.path.join(project_name, "settings.gradle"), "w") as f:
        f.write("include ':app'")

    # 3. app/build.gradle (basic)
    basic_deps = "implementation 'androidx.appcompat:appcompat:1.7.0'\n    implementation 'androidx.core:core-ktx:1.13.1'"
    app_build_gradle_content = f"""plugins {{
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
}}

android {{
    namespace 'com.example.app' // TODO: Replace with actual package name
    compileSdk 34

    defaultConfig {{
        applicationId "com.example.app" // TODO: Replace with actual package name
        minSdk 24
        targetSdk 34
        versionCode 1
        versionName "1.0"

        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }}

    buildTypes {{
        release {{
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }}
    }}
    compileOptions {{
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }}
    kotlinOptions {{
        jvmTarget = '17'
    }}
}}

dependencies {{
    {basic_deps}
    // Add auto-detected dependencies here
}}
"""
    with open(os.path.join(project_name, "app", "build.gradle"), "w") as f:
        f.write(app_build_gradle_content)

    # 4. debug.keystore (Placeholder)
    log_info("Gerando keystore de debug (placeholder)...")
    with open(os.path.join(project_name, "app", "debug.keystore"), "w") as f:
        f.write("Placeholder Keystore")

    # 5. gradlew (Placeholder - em um ambiente real, seria necessário o binário)
    log_info("Criando placeholder para gradlew...")
    with open(os.path.join(project_name, "gradlew"), "w") as f:
        f.write("#!/bin/bash\necho 'Execute o build com o gradlew real ou importe no Android Studio.'")
    os.chmod(os.path.join(project_name, "gradlew"), 0o755)

    log_info("[bold green]Configuração Gradle concluída.[/bold green]")

def detect_and_inject_dependencies(project_name):
    """Detecta dependências comuns no código descompilado e as injeta no build.gradle."""
    log_info("Detectando e adicionando dependências avançadas...")
    
    app_build_gradle_path = os.path.join(project_name, "app", "build.gradle")
    code_dir = os.path.join(project_name, "app", "src", "main", "java")
    
    detected_deps = []
    
    # Lista de dependências e padrões de importação para detecção
    detection_map = {
        "kotlinx-coroutines": {
            "pattern": r'kotlinx\.coroutines',
            "dep": "implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3'"
        },
        "retrofit2": {
            "pattern": r'retrofit2',
            "dep": "implementation 'com.squareup.retrofit2:retrofit:2.9.0'"
        },
        "room": {
            "pattern": r'androidx\.room',
            "dep": "implementation 'androidx.room:room-runtime:2.6.1'\n    kapt 'androidx.room:room-compiler:2.6.1'"
        },
        "hilt": {
            "pattern": r'dagger\.hilt',
            "dep": "implementation 'com.google.dagger:hilt-android:2.48'\n    kapt 'com.google.dagger:hilt-compiler:2.48'"
        },
        "glide": {
            "pattern": r'com\.bumptech\.glide',
            "dep": "implementation 'com.github.bumptech.glide:glide:4.16.0'\n    annotationProcessor 'com.github.bumptech.glide:compiler:4.16.0'"
        }
    }

    # 1. Verificar se há arquivos Kotlin para adicionar o plugin
    if any(f.endswith(".kt") for root, _, files in os.walk(code_dir) for f in files):
        log_info("Kotlin detectado. Garantindo plugin Kotlin no app/build.gradle.")
        # O plugin já está no template, mas podemos adicionar outras libs Kotlin se necessário
        # Exemplo: Coroutines
        if "kotlinx-coroutines" not in detected_deps:
            detected_deps.append(detection_map["kotlinx-coroutines"]["dep"])

    # 2. Procurar padrões de importação no código-fonte
    for dep_name, data in detection_map.items():
        if dep_name == "kotlinx-coroutines": # Já tratada acima
            continue
            
        pattern = data["pattern"]
        
        # Usar grep para procurar o padrão nos arquivos .java e .kt
        try:
            # Encontrar arquivos .java ou .kt que contenham o padrão
            find_command = f"grep -r '{pattern}' {code_dir} --include='*.java' --include='*.kt' -l"
            result = subprocess.run(find_command, shell=True, capture_output=True, text=True, check=True)
            
            if result.stdout.strip():
                log_info(f"Padrão '{pattern}' detectado para [bold yellow]{dep_name}[/bold yellow]. Adicionando dependência.")
                detected_deps.append(data["dep"])
            
        except subprocess.CalledProcessError:
            # Grep retorna código 1 se não encontrar nada, o que é normal.
            pass
        except Exception as e:
            log_info(f"[yellow]Aviso: Falha na detecção de dependência para {dep_name}: {e}[/yellow]")

    # 3. Injetar dependências detectadas no app/build.gradle
    if detected_deps:
        log_info(f"Injetando {len(detected_deps)} dependências detectadas no app/build.gradle.")
        deps_to_inject = "\n    ".join(detected_deps)
        
        # Ler o conteúdo atual
        with open(app_build_gradle_path, "r") as f:
            content = f.read()
            
        # Substituir o placeholder
        new_content = content.replace("// Add auto-detected dependencies here", deps_to_inject)
        
        # Escrever de volta
        with open(app_build_gradle_path, "w") as f:
            f.write(new_content)
    else:
        log_info("Nenhuma dependência avançada detectada.")

def apply_proguard_mapping(project_name):
    """Aplica o mapeamento ProGuard (mapping.txt) ao código-fonte descompilado."""
    # O mapping.txt é esperado no mesmo diretório onde o comando 'apksource' foi executado.
    mapping_file = os.path.join(os.getcwd(), "mapping.txt")
    code_dir = os.path.join(project_name, "app", "src", "main", "java")

    if not os.path.exists(mapping_file):
        log_info("Arquivo [bold yellow]mapping.txt[/bold yellow] não encontrado no diretório atual. Pulando desofuscação avançada.")
        return

    log_info(f"Arquivo [bold yellow]mapping.txt[/bold yellow] encontrado. Aplicando desofuscação no código em [dim]{code_dir}[/dim]...")

    mappings = {}
    try:
        with open(mapping_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue

                # Padrão para mapeamento de classes: obfuscated.class.name -> original.class.name
                class_match = re.match(r'(.+?) -> (.+?):', line)
                if class_match:
                    obf_name = class_match.group(1).replace('.', '/')
                    orig_name = class_match.group(2).replace('.', '/')
                    mappings[obf_name] = orig_name
                    continue

                # Padrão para mapeamento de membros (campos/métodos)
                # Exemplo: 1:1:void a(android.content.Context) -> showToast
                # O mapeamento de membros é complexo e requer análise de AST, o que está além do escopo
                # de uma migração simples de Bash. Focaremos na renomeação de classes.
                pass

    except Exception as e:
        log_info(f"[bold red]Aviso:[/bold red] Falha ao ler ou analisar mapping.txt: {e}")
        return

    if not mappings:
        log_info("Nenhum mapeamento de classe válido encontrado no mapping.txt. Pulando.")
        return

    # 1. Renomear arquivos e diretórios
    log_info("Renomeando arquivos e diretórios de classes...")
    for obf_path, orig_path in track(mappings.items(), description="Renomeando classes..."):
        obf_file_java = os.path.join(code_dir, f"{obf_path}.java")
        orig_file_java = os.path.join(code_dir, f"{orig_path}.java")
        
        obf_file_kt = os.path.join(code_dir, f"{obf_path}.kt")
        orig_file_kt = os.path.join(code_dir, f"{orig_path}.kt")

        if os.path.exists(obf_file_java):
            obf_file = obf_file_java
            orig_file = orig_file_java
        elif os.path.exists(obf_file_kt):
            obf_file = obf_file_kt
            orig_file = orig_file_kt
        else:
            continue

        # Garantir que o diretório de destino exista
        os.makedirs(os.path.dirname(orig_file), exist_ok=True)

        try:
            # Renomear o arquivo
            shutil.move(obf_file, orig_file)
            
            # Atualizar o nome da classe e o pacote dentro do arquivo
            with open(orig_file, 'r') as f:
                content = f.read()

            # Extrair apenas o nome da classe (último componente do path)
            obf_class_name = os.path.basename(os.path.splitext(obf_file)[0])
            orig_class_name = os.path.basename(os.path.splitext(orig_file)[0])

            # Substituir o nome da classe e o pacote
            
            # 1. Substituir o nome da classe (melhorado com regex para ser mais específico)
            # Procura por 'class ObfName', 'interface ObfName', 'enum ObfName', etc.
            new_content = re.sub(
                rf'(\b(?:class|interface|enum)\s+){re.escape(obf_class_name)}(\b)', 
                rf'\1{orig_class_name}\2', 
                content, 
                count=1 # Apenas o primeiro (definição da classe)
            )

            # 2. Corrigir a declaração do pacote
            orig_package = os.path.dirname(orig_path).replace('/', '.')
            new_content = re.sub(r'package\s+.*?;', f'package {orig_package};', new_content, count=1)

            with open(orig_file, 'w') as f:
                f.write(new_content)

        except Exception as e:
            log_info(f"[bold red]Aviso:[/bold red] Falha ao renomear/atualizar {obf_file}: {e}")
            continue

    log_info("[bold green]Desofuscação de classes concluída.[/bold green]")

def decompile_apk(apk_path, project_name):
    """Executa o processo completo de descompilação."""
    
    # 1. Decompilação de Recursos (apktool)
    res_dir = os.path.join(project_name, "app", "src", "main", "res")
    log_info(f"Descompilando recursos com [bold yellow]apktool[/bold yellow] para [dim]{res_dir}[/dim]...")
    apktool_cmd = f"apktool d -f -o {res_dir} {apk_path}"
    run_decompile_command(apktool_cmd, "Descompilação de Recursos (apktool)")

    # 2. Decompilação de Código (jadx)
    code_dir = os.path.join(project_name, "app", "src", "main", "java")
    log_info(f"Descompilando código com [bold yellow]jadx[/bold yellow] para [dim]{code_dir}[/dim]...")
    # jadx -d <out_dir> -s <src_dir> <file>
    # Usamos -s para salvar o código-fonte
    jadx_cmd = f"jadx -d {code_dir} -s {code_dir} {apk_path}"
    run_decompile_command(jadx_cmd, "Descompilação de Código (jadx)")

    # 3. Configuração do Projeto Gradle
    setup_gradle_project(project_name)

    # 4. Detecção e Injeção de Dependências
    detect_and_inject_dependencies(project_name)

    # 5. Aplicação do Mapeamento ProGuard (Desofuscação)
    apply_proguard_mapping(project_name)

    log_info(f"Processo de descompilação e configuração concluído em [bold green]{project_name}[/bold green].")