import click
import sys
import os
import shutil
from datetime import datetime
from rich.console import Console
from rich.panel import Panel
from .core import check_all_dependencies, decompile_apk, smart_project_name, ApkSourceError, log_info

VERSION = "1.3.0"
console = Console()

def print_help_menu(ctx):
    """Exibe o menu de ajuda completo."""
    console.print(Panel(
        f"[bold cyan]ApkSource[/bold cyan] [dim]v{VERSION}[/dim]",
        subtitle="Transforme APK em código-fonte Gradle pronto para Android Studio.",
        border_style="cyan"
    ))
    click.echo(ctx.get_help())

@click.group(invoke_without_command=True)
@click.option('-v', '--version', is_flag=True, help='Exibe a versão do ApkSource.')
@click.pass_context
def main(ctx, version):
    """
    ApkSource é uma ferramenta para descompilar APKs e gerar projetos Gradle.
    """
    if version:
        console.print(f"ApkSource v{VERSION}")
        sys.exit(0)

    if ctx.invoked_subcommand is None:
        print_help_menu(ctx)
        sys.exit(0)

@main.command()
@click.argument('apk_path', type=click.Path(exists=True))
@click.option('--skip-backup', is_flag=True, default=False, help='Pula o backup se o diretório do projeto já existir.')
@click.option('--project-name', type=str, default=None, help='Define um nome personalizado para o diretório do projeto.')
def decompile(apk_path, skip_backup, project_name):
    """
    Descompila um arquivo APK e gera um projeto Gradle.

    APK_PATH: Caminho para o arquivo APK a ser descompilado.
    """
    try:
        # 0. Verificar dependências
        check_all_dependencies()

        # 1. Definir nome do projeto
        if not project_name:
            project_name = smart_project_name(apk_path)

        log_info(f"Nome do projeto definido como: [bold yellow]{project_name}[/bold yellow]")

        # 2. Lidar com diretório existente
        if os.path.exists(project_name):
            if skip_backup:
                log_info(f"Diretório [dim]{project_name}[/dim] existe. Pulando backup conforme solicitado.")
            else:
                backup_name = f"{project_name}.bak.{datetime.now().strftime('%Y%m%d%H%M%S')}"
                log_info(f"Diretório [dim]{project_name}[/dim] já existe. Fazendo backup para [dim]{backup_name}[/dim]...")
                shutil.move(project_name, backup_name)

        # 3. Criar diretórios necessários
        os.makedirs(os.path.join(project_name, "app", "src", "main", "java"), exist_ok=True)
        os.makedirs(os.path.join(project_name, "app", "src", "main", "res"), exist_ok=True)

        # 4. Iniciar descompilação
        decompile_apk(apk_path, project_name)

        console.print("[bold green]✅ Descompilação concluída com sucesso![/bold green]")

    except ApkSourceError as e:
        console.print(f"[bold red]FALHA CRÍTICA:[/bold red] {e.args[0]}")
        sys.exit(1)
    except Exception as e:
        console.print(f"[bold red]ERRO INESPERADO:[/bold red] {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()