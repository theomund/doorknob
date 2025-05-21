// Doorknob - Artificial intelligence companion written in Gleam.
// Copyright (C) 2025 Theomund
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import envoy
import logging.{Debug, Error as Err, Info, Warning}

pub fn setup() -> Nil {
  logging.configure()

  let level = case envoy.get("LOG_LEVEL") {
    Error(_) -> {
      logging.log(Warning, "Couldn't find log level: setting it to INFO")
      Info
    }
    Ok("DEBUG") -> Debug
    Ok("ERROR") -> Err
    Ok("INFO") -> Info
    Ok("WARN") -> Warning
    Ok(_) -> {
      logging.log(Err, "Couldn't parse log level: setting it to INFO")
      Info
    }
  }

  logging.set_level(level)
}
