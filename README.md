# mysku

An app for privacy-preserving location sharing with lots of friends, alumni groups, etc.

### todo to "finish" basic vision

- [x] Get background location updating working (what the fuck apple. your apis fail silently. how am i supposed to fix anything.)
- [ ] Make backend db production ready
- [ ] Get notifications working on friend traveling closeish

### app store considerations

Our app provides group location sharing and alerts users if a friend is visiting their city. This functionality only works with background location updates, as friends may travel without actively using the app. We use location once daily to update a user’s city location and notify their approved friends/groups (e.g. via Discord integration).

### notes to not forget

let's get this working at some point so we can get list of friends and share that way too.

```
relationships.read
allows your app to know a user's friends and implicit relationships - requires Discord approval
```
