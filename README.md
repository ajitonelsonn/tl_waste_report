# TL Waste Report App

![tag:innovation-lab](https://img.shields.io/badge/innovation--lab-3D8BD3)
![tag:waste-management](https://img.shields.io/badge/waste--management-4CAF50)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue.svg)

A mobile application that enables citizens of Timor-Leste to report waste issues in their communities. Built with Flutter for the Global AI Agents League Hackathon.

## Features

- **User Authentication**: Secure registration and login with OTP verification
- **Report Submission**: Capture and submit waste reports with images, location data, and descriptions
- **Image Optimization**: Smart compression of images before upload to save bandwidth
- **Report Tracking**: View the status and analysis results of your submitted reports
- **Interactive Map**: View waste reports and hotspots on an interactive map
- **Profile Management**: Update user information and track personal statistics

## Architecture

The TL Waste Report App follows a provider-based architecture with the following components:

- **Providers**: State management and business logic
- **Screens**: User interface components
- **Services**: API communication and device interactions
- **Models**: Data structures for the application
- **Utils**: Helper functions and utilities

## Technologies Used

- **Flutter**: Cross-platform UI toolkit
- **Provider**: State management
- **http/dio**: API communication
- **flutter_secure_storage**: Secure storage for tokens
- **geolocator/geocoding**: Location services
- **flutter_map**: Map visualization
- **image_picker/flutter_image_compress**: Image handling and optimization
- **connectivity_plus**: Network connectivity detection

## Getting Started

### Prerequisites

- Flutter SDK (2.10.0 or higher)
- Dart SDK (2.16.0 or higher)
- Android Studio or VS Code with Flutter extensions
- An emulator or physical device for testing

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/ajitonelsonn/tl_waste_report.git
   cd tl_waste_report
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Create a `.env` file in the project root with the following variables:
   ```
   API_BASE_URL=http://localhost:5002
   REPORTING_AGENT_URL=http://localhost:5001
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── config/               # App configuration
├── models/               # Data models
├── providers/            # State management
├── screens/              # UI screens
├── services/             # API and device services
├── utils/                # Helper utilities
├── widgets/              # Reusable UI components
└── main.dart             # Entry point
```

## Key Screens

- **Splash Screen**: Initial loading screen with app branding
- **Login/Register Screens**: User authentication interfaces
- **Home Screen**: Overview of reports and status
- **Report Screen**: Submit new waste reports with camera and location
- **Map Screen**: Interactive map showing reports and hotspots
- **Profile Screen**: User profile management
- **Report Detail Screen**: Detailed view of individual reports

## App Flow

1. Users register or login with mobile number/email
2. After authentication, users can submit reports about waste issues
3. Reports include location data, images, and descriptions
4. Submitted reports are sent to the central waste monitoring system
5. The AI-powered analysis agent processes the reports
6. Users can track the status of their reports and view analysis results
7. Users can explore nearby waste reports and hotspots on the map

## Future Enhancements

- Multi-language support
- Push notifications for report status updates
- Gamification features to encourage community participation
- Integration with waste collection schedules
- Enhanced offline capabilities with local database


## Acknowledgements

- The Global AI Agents League Hackathon
- Fetch.ai for providing the agent framework
- Open-source Flutter community

## ALL TL Digital Waste Monitoring Network REPO
- [TL Digital Waste Monitoring Network](https://github.com/ajitonelsonn/TLWasteR) - Main repo just explanation
- [TL-WASTE-MONITORING](https://github.com/ajitonelsonn/tl-waste-monitoring) - API for agents and others
- [TL Waste Report App](https://github.com/ajitonelsonn/tl_waste_report) - Flutter mobile application for citizens
- [TL Waste Dashboard](https://github.com/ajitonelsonn/tl-waste-dashboard) - Next.js web dashboard for public