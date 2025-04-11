# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

- `cd backend && npm run dev` - Run backend server in development
- `cd backend && npm run build` - Build backend for production
- `cd backend && npm run start` - Start production backend server
- `cd backend && npx tsc --noEmit` - TypeScript validation
- `./scripts/run-uitests.sh` - Run Swift UI tests and export screenshots to a folder

## Code Style

- **TypeScript**: ESM modules, strict typing, 2-space indent, async/await patterns
- **Swift**: SwiftUI with MVVM, 4-space indent, ObservableObject for state
- **Error Handling**: Use try/catch in async functions, propagate errors upward
- **Naming**: camelCase for variables/methods, PascalCase for types/classes
- **Imports**: Group imports by source (system, third-party, local)
- **Comments**: Use MARK for Swift section headers, document public interfaces

## Project Structure

- Backend: Express API with TypeScript, JSON storage (dev)
- iOS: Native Swift app using SwiftUI, Discord OAuth authentication
- Tests: XCTest for UI testing with screenshot capture capability
