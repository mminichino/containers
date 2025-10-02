import tomli
from dataclasses import dataclass
from typing import Optional


@dataclass
class GitHub:
    owner: str
    repo: str


@dataclass
class Docker:
    repo: str


@dataclass
class Repo:
    github: Optional[GitHub] = None
    docker: Optional[Docker] = None

    def __init__(self, file_path: str):
        with open(file_path, 'rb') as f:
            data = tomli.load(f)

        if 'github' in data:
            self.github = GitHub(
                owner=data['github']['owner'],
                repo=data['github']['repo']
            )

        if 'docker' in data:
            self.docker = Docker(
                repo=data['docker']['repo']
            )
