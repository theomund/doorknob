# Doorknob - Artificial intelligence companion written in Elixir.
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
RUN sed -i '/tsflags=nodocs/d' /etc/dnf/dnf.conf
RUN dnf copr enable -y theomund/copr \
    && dnf install -y \
    bash-completion-2.16 \
    elixir-1.18.3 \
    erlang-26.2.5.12 \
    gawk-5.3.1 \
    git-2.49.0 \
    hadolint-2.12.0 \
    just-1.40.0 \
    vale-3.11.2 \
    which-2.23 \
    yamllint-1.37.0 \
    && dnf clean all
RUN useradd -m developer
USER developer
