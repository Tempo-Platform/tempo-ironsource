# TempoSDK

## To Run Example app

1. Run `cd Example`
2. Run `pod install`. This installs all the pod dependencies and creates a "TempoSDK.xcworkspace" file.
3. Open the file "Example/TempoSDK.xcworkspace" in XCode
4. Hit Run

## To Publish a new version of cocoapods
1. Create a new release in github with an updated version number.
2. Update the version number in "TempoSDK.podspec" file to match the above github release. 
3. Run `pod trunk push --allow-warnings --verbose`

## To try the TempoSDK in your project

Add the following line to your Podfile:

```ruby
pod 'TempoSDK'
```
