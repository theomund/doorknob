# Doorknob - Artificial intelligence companion written in Gleam.
# Copyright (C) 2025 Theomund
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

FROM quay.io/fedora/fedora:42
RUN dnf config-manager addrepo --from-repofile=https://mise.jdx.dev/rpm/mise.repo \
    && dnf install -y \
    automake-1.17 \
    bash-completion-2.16 \
    gawk-5.3.1 \
    gcc-c++-15.1.1 \
    git-2.49.0 \
    gnupg2-2.4.7 \
    mise-2025.5.6 \
    openssl-devel-3.2.4 \
    ncurses-devel-6.5 \
    procps-ng-4.0.4 \
    && dnf clean all
RUN useradd -m developer
USER developer
ENV PATH="$PATH:/home/developer/.local/share/mise/shims"
RUN mise install erlang@27.3.4 gleam@1.10.0 rebar@3.24.0 vale@3.11.2
