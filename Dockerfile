FROM ubuntu:22.04

# Avoid interactive dialogue during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set environment variables
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV FLUTTER_HOME=/opt/flutter
ENV PATH=$FLUTTER_HOME/bin:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH

# Install necessary packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-11-jdk \
    wget \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    && rm -rf /var/lib/apt/lists/*

# Download and install Android SDK Command-line tools
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip && \
    unzip commandlinetools-linux-*_latest.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools && \
    mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest && \
    rm commandlinetools-linux-*_latest.zip

# Accept Android SDK licenses
RUN yes | sdkmanager --licenses

# Install Android SDK components
RUN sdkmanager \
    "platform-tools" \
    "platforms;android-33" \
    "build-tools;33.0.0" \
    "system-images;android-33;google_apis;x86_64" \
    "emulator"

# Accept licenses
RUN yes | sdkmanager --licenses

# Create Android Virtual Device
RUN echo "no" | avdmanager create avd \
    -n Pixel_6_API_33 \
    -k "system-images;android-33;google_apis;x86_64" \
    -d "pixel_6" \
    --force

# Download Flutter SDK
RUN git clone https://github.com/flutter/flutter.git -b stable $FLUTTER_HOME

# Run basic Flutter commands to download Dart SDK and other dependencies
RUN flutter doctor
RUN flutter config --no-analytics
RUN flutter precache

# Set the working directory
WORKDIR /app

# Create a non-root user
# RUN useradd -ms /bin/bash developer
# USER developer

# Command to run when starting the container
CMD ["bash"]
# Add X11 and GUI dependencies
RUN apt-get update && apt-get install -y \
    x11-apps \
    xauth \
    libxv1 \
    libglu1-mesa \
    libegl1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Android emulator dependencies
RUN apt-get update && apt-get install -y \
    qemu-kvm \
    bridge-utils \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
RUN apt-get update && apt-get install -y \
    openjdk-17-jdk