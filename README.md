# mysku

An app for privacy-preserving location sharing with lots of friends, alumni groups, etc.

## User Interface

mysku features a clean, intuitive interface designed for privacy-conscious location sharing:

- **Launch & Authentication**: Simple login flow for secure account access
- **Map View**: Central interface showing friends' locations with privacy controls
- **Settings**: Comprehensive options for account management, notifications, and location privacy

See the [screenshots directory](./screenshots) for visual examples of the UI.

## Development

If changing the backend edit `mysku/Constants.swift`

### Testing

Run

```
xcodebuild -scheme mysku -showdestinations
```

Then pick one and paste the id like so:

```
xcodebuild test -scheme mysku -destination "platform=iOS,id=00008101-001434D40081401E"
```

To run automated tests.

