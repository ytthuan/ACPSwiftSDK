# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- _None yet._

## [0.1.3] - 2026-03-04

### Added
- Added `line` to `ToolCallLocation` for ACP spec alignment.
- Added `annotations` support to `EmbeddedResource` and `ResourceContent`.
- Added doc comments for spec-required fields.
- Added 6 new ACP spec compliance tests.

### Changed
- Updated `CurrentModeUpdate` to use spec field name `currentModeId`.
- Updated `PermissionOption` encoding to use spec field names (`optionId`, `name`).

## [0.1.2] - 2026-03-03

### Added
- Added ACP client-side support for `authenticate`, `fs/read_text_file`, `fs/write_text_file`,
  and terminal methods (`terminal/create`, `terminal/output`, `terminal/wait_for_exit`,
  `terminal/kill`, `terminal/release`).
- Added ACP schema/model coverage for `authMethods`, image `uri`, resource link `title`/`size`,
  config option `description`, plan entry `content`, terminal tool `terminalId`, and `_meta`
  support for content blocks.
- Added ACP spec compliance tests and malformed terminal request safety tests.

### Fixed
- Hardened terminal request handlers to avoid force-unwrapping crashes on malformed JSON-RPC
  requests.

## [0.1.1] - 2026-03-03

### Added
- Added CI and tag-based release workflows to automate stable release publication.
