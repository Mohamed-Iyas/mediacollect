# Shots Studio

## How to Build the APK

### Local Build

If you have a local Flutter development environment set up, you can build the APK manually by running the following command from within the `shots_studio` directory:

```bash
flutter build apk --release
```

This will place the generated APK in `shots_studio/build/app/outputs/flutter-apk/app-release.apk`.

### GitLab CI/CD

The APK is also built automatically via a GitLab CI/CD pipeline. Here's how to download it:

1.  **Find the Pipeline:** Navigate to the project's **CI/CD > Pipelines** section in GitLab.
2.  **Locate the Job:** Look for the latest pipeline that ran for your branch. Inside that pipeline, you will find a job named `build_apk`.
3.  **Download the APK:** Click on the `build_apk` job. On the job's page, you will find a section on the right side labeled **Job artifacts**. You can download the `app-release.apk` file from there.
