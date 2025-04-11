# mysku

An app for privacy-preserving location sharing with lots of friends, alumni groups, etc.

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

