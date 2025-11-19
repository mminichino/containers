##

import logging
import subprocess
import typer
import os
import requests
import shutil

from typing import Iterator, Optional, List, Tuple
from typing_extensions import Annotated
from pathlib import Path

from .repo import Repo
from .versions import is_version, get_latest_versions

app = typer.Typer()
logger = logging.getLogger()


def build_image(
        repo: str,
        image_name: str,
        version: str,
        platform: str = "linux/amd64,linux/arm64"
):
    args = [
        "docker", "buildx", "build",
        "--platform", platform,
        "--build-arg", f"VERSION={version}",
        "--sbom=true",
        "--provenance=true",
        "-t", f"{repo}/{image_name}:{version}",
        "--push",
        "."
    ]
    subprocess.run(args, check=True)

def get_images() -> Iterator[str]:
    images_path = "images"
    for d in os.listdir(images_path):
        if os.path.isdir(os.path.join(images_path, d)):
            yield d

def get_versions(image: str) -> Tuple[Optional[Repo], List[str]]:
    repo_cfg_path = f"images/{image}/repo.toml"
    tags: List[str] = []
    repo: Optional[Repo] = None

    if os.path.exists(repo_cfg_path):
        repo = Repo(repo_cfg_path)
        if repo.github:
            repo_tags: List[str] = []
            for tag in get_tags(repo.github.owner, repo.github.repo):
                if is_version(tag):
                    repo_tags.append(tag)
            tags.extend(get_latest_versions(repo_tags))
        elif repo.source:
            tags.extend(repo.source.keys())

    return repo, tags

def get_tags(owner: str, repo: str, token: Optional[str] = None) -> Iterator[str]:
    url = f"https://api.github.com/repos/{owner}/{repo}/tags"
    headers = {"Authorization": f"token {token}"} if token else {}

    response = requests.get(url, headers=headers)
    response.raise_for_status()

    for tag in response.json():
        yield tag["name"]

def create_repo(repo: Repo, image: str, version: str, latest: bool, platform: str, overwrite: bool = False):
    repo_dir = f"images/{image}/{version}"
    docker_file = f"images/{image}/Dockerfile"
    version_docker_file = f"images/{image}/{version}/Dockerfile"

    if os.path.exists(docker_file):
        if os.path.exists(repo_dir) and not overwrite:
            return
        Path(repo_dir).mkdir(parents=True, exist_ok=True)
        shutil.copy(docker_file, version_docker_file)
        current_dir = os.getcwd()
        os.chdir(repo_dir)

        source = repo.source.get(version) if repo.source else None
        if source.path and os.path.exists(source.path):
            source_path = "source"
            Path(source_path).mkdir(parents=True, exist_ok=True)
            if os.path.isfile(source.path):
                destination = os.path.basename(source.path)
                shutil.copy(source.path, f"{source_path}/{destination}")
            else:
                shutil.copytree(source.path, f"{source_path}/")

        versions = [version, "latest"] if latest else [version]

        for tag in versions:
            print(f"Building {image}:{tag}")
            build_image(
                repo.docker.repo,
                image,
                tag,
                platform
            )

        print("Done.")
        os.chdir(current_dir)

@app.command()
def build(
        image: Annotated[str, typer.Argument(help="Image name")] = None,
        overwrite: bool = typer.Option(False, "--overwrite", help="Recreate containers"),
        platform: str = typer.Option("linux/amd64,linux/arm64", "--platform", help="Platform")
):
    print("Building...")

    for image_name in get_images():
        if image and image != image_name:
            continue
        repo, versions = get_versions(image_name)
        if not versions or not repo or not repo.docker:
            continue
        for n, version in enumerate(versions):
            is_latest = (n == len(versions) - 1)
            create_repo(repo, image_name, version, is_latest, platform, overwrite)


if __name__ == "__main__":
    app()
