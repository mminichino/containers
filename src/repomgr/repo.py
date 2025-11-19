import tomli
import os
from dataclasses import dataclass, field
from typing import Optional, Dict


@dataclass
class GitHub:
    owner: str
    repo: str


@dataclass
class Docker:
    repo: str


@dataclass
class Source:
    path: str


@dataclass
class Repo:
    github: Optional[GitHub] = None
    docker: Optional[Docker] = None
    source: Dict = field(default_factory=dict)

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

        if 'source' in data:
            self.source = {}
            for source in data['source']:
                self.source[source['version']] = Source(
                    path=os.path.expanduser(source['path'])
                )
