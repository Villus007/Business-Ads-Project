# Personal-Project - Business Ad Platform

A Flutter application for managing business advertisements with AWS integration.

## Project Overview

This is a cross-platform Flutter application that allows users to:
- Create and submit business advertisements
- Upload images using AWS S3 with pre-signed URLs
- View featured and all business ads
- Integrated with AWS API Gateway and Lambda functions

## Features

- **AWS Integration**: Full backend integration with AWS services
- **Image Upload**: Secure image upload using pre-signed URLs
- **Cross-Platform**: Supports Android, iOS, Web, Windows, macOS, and Linux
- **Modern UI**: Clean and intuitive user interface
- **Real-time Data**: Fetches and displays ads from AWS in real-time

## Technical Stack

- **Frontend**: Flutter/Dart
- **Backend**: AWS (API Gateway, Lambda, S3, CloudFront)
- **Database**: AWS DynamoDB (via Lambda)
- **Image Storage**: AWS S3 with CloudFront CDN
- **Build System**: Gradle with Java 17, Android NDK 27.0.12077973

## Getting Started

This project is a starting point for a Flutter application with AWS backend integration.

### Prerequisites

- Flutter SDK
- Java 17 (for Android development)
- Android Studio or VS Code
- AWS account (for backend services)

### Installation

1. Clone this repository
2. Run `flutter pub get` to install dependencies
3. Configure your AWS endpoints in `lib/services/api_service.dart`
4. Run `flutter run` to start the application

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [AWS SDK for Flutter](https://docs.aws.amazon.com/amplify/latest/userguide/getting-started.html)
- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
