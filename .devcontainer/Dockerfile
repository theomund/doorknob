# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

FROM quay.io/fedora/fedora:44
RUN dnf copr enable -y sisyphus1813/odin-lang \
    && dnf install -y \
    bash-completion-2.17 \
    clang-22.1.8 \
    git-2.55.0 \
    hadolint-2.14.0 \
    kcov-43 \
    libcurl-devel-8.18.0 \
    mbedtls-devel-3.6.6 \
    odin-lang-2026.07 \
    ols-2026.05 \
    yamllint-1.38.0 \
    && dnf clean all
RUN useradd -m developer
WORKDIR /home/developer
USER developer
