# Doorknob - Artificial intelligence companion written in Rust.
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
RUN dnf copr enable -y theomund/copr \
    && dnf install -y \
    bash-completion-2.16 \
    cmake-3.31.6 \
    gawk-5.3.1 \
    gcc-15.1.1 \
    git-2.49.0 \
    gnupg2-2.4.7 \
    just-1.40.0 \
    lldb-20.1.6 \
    openssl-devel-3.2.4 \
    opus-devel-1.5.2 \
    rustup-1.28.2 \
    vale-3.12.0 \
    yamllint-1.37.1 \
    yt-dlp-2025.05.22 \
    && dnf clean all
RUN useradd -m developer
USER developer
RUN rustup-init -y --default-toolchain 1.87.0
