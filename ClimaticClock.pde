import ddf.minim.*;
import java.time.ZonedDateTime;
import java.time.ZoneId;

String[] cities = {"Ankara", "Chicago", "London", "Kolkata"};
String[] zones = {"Europe/Istanbul", "America/Chicago", "Europe/London", "Asia/Kolkata"};
int[] hours = new int[cities.length];

Minim minim;
AudioPlayer clockPlayer, dialPlayer, dialStartPlayer, callPlayer;
AudioPlayer cloudsPlayer, clearPlayer, rainPlayer;

int clockRadius = 170;
int prevSecond = -1;
boolean grabbingHourHand = false;
float grabbedHourAngle = 0, currentHourAngle = 0;
boolean returningHourHand = false;
float returnStartAngle = 0, targetHourAngle = 0, returnStartTime = 0;
float returnDuration = 1000;
boolean callPlayScheduled = false;
int callPlayTime = -1;

boolean waitingBeforeReturn = false;
int hourHandReleaseTime = -1;
float snappedAngleAfterRelease = 0;
int lastDialPlayTime = 0;
int dialCooldown = 300;
int lastDialStartPlayTime = 0;
int dialStartCooldown = 2000;
boolean hasMoved = false;
boolean isCall = false;
String weatherType = "";
String matchedCity = "Japan";

PImage img;
float alpha = 0;
int fadeDuration = 3000;   
int holdDuration = 3000;  
int totalDuration;        
int startTime;

FadeImage images;

void setup() {
  size(800, 500);
  strokeCap(PROJECT);
  minim = new Minim(this);
  clockPlayer = minim.loadFile("clock.wav");
  dialPlayer = minim.loadFile("dial.wav");
  dialStartPlayer = minim.loadFile("dialStart.wav");
  callPlayer = minim.loadFile("call.mp3");
  cloudsPlayer = minim.loadFile("clouds.mp3");
  rainPlayer = minim.loadFile("rain.mp3");
  clearPlayer = minim.loadFile("clear.mp3");
  frameRate(30);
  textAlign(CENTER, CENTER);
  currentHourAngle = (hour() % 12) * 30 + minute() * 0.4f;
  targetHourAngle = currentHourAngle;

  for (int i = 0; i < cities.length; i++) {
    ZonedDateTime zdt = ZonedDateTime.now(ZoneId.of(zones[i]));
    hours[i] = zdt.getHour() % 12;
    println(cities[i] + ": " + hours[i]);
  }
}

void draw() {
  background(230);
  translate(width / 2, height / 2);
  clockFace();
  boolean overHour = !grabbingHourHand && isMouseOverHand(currentHourAngle, clockRadius * 0.5f);

  if (returningHourHand) {
    float t = (millis() - returnStartTime) / returnDuration;
    if (t >= 1) {
      t = 1;
      returningHourHand = false;
      currentHourAngle = targetHourAngle;
      callPlayScheduled = true;
      callPlayTime = millis() + 3000;
    } else {
      float delta = (targetHourAngle - returnStartAngle + 540) % 360 - 180;
      currentHourAngle = (returnStartAngle + delta * t + 360) % 360;
    }
  } else if (waitingBeforeReturn && millis() - hourHandReleaseTime >= 2000) {
    waitingBeforeReturn = false;
    returnStartAngle = snappedAngleAfterRelease;
    targetHourAngle = (hour() % 12) * 30 + minute() * 0.4f;
    returnStartTime = millis();
    returningHourHand = true;
    if (millis() - lastDialPlayTime > dialCooldown) {
      dialPlayer.rewind();
      dialPlayer.play();
      lastDialPlayTime = millis();
    }
  }

  drawHands(overHour);
  playClockTick();
  handleCallAndWeather();

  stroke(5);
  fill(5);
  ellipse(0, 0, clockRadius * 0.125, clockRadius * 0.125);

  if (images != null) {
    resetMatrix();
    images.update();
    images.display();
    translate(width / 2, height / 2);
  }
}

void drawHands(boolean overHour) {
  pushMatrix();
  rotate(radians(grabbingHourHand ? grabbedHourAngle : currentHourAngle));
  hourHand((grabbingHourHand || overHour) ? color(255, 0, 0) : color(45));
  popMatrix();

  pushMatrix();
  rotate(radians(minute() * 6));
  minuteHand(color(30));
  popMatrix();

  pushMatrix();
  rotate(radians(second() * 6));
  secondHand(color(15));
  popMatrix();
}

void playClockTick() {
  int currentSecond = second();
  if (currentSecond != prevSecond) {
    clockPlayer.rewind();
    clockPlayer.play();
    prevSecond = currentSecond;
  }
}

void handleCallAndWeather() {
  if (callPlayScheduled && millis() >= callPlayTime && isCall) {
    callPlayer.rewind();
    callPlayer.play();
    switch (weatherType) {
      case "Clouds":
        images = new FadeImage("clouds.png", 3000, 10000, 3000, 0);
        cloudsPlayer.rewind();
        cloudsPlayer.play();
        break;
      case "Rain":
        images = new FadeImage("rain.png", 3000, 10000, 3000, 0);
        rainPlayer.rewind();
        rainPlayer.play();
        break;
      case "Clear":
        images = new FadeImage("clear.png", 3000, 10000, 3000, 0);
        clearPlayer.rewind();
        clearPlayer.play();
        break;
      default:
        images = new FadeImage("clear.png", 3000, 10000, 3000, 0);
        clearPlayer.rewind();
        clearPlayer.play();
    }
    callPlayScheduled = false;
    isCall = false;
  }
}

boolean isMouseOverHand(float handAngleDegrees, float handLength) {
  float mx = mouseX - width / 2;
  float my = mouseY - height / 2;
  float handAngle = radians(handAngleDegrees - 90);
  float hx = cos(handAngle);
  float hy = sin(handAngle);
  float distAlong = mx * hx + my * hy;
  if (distAlong < 0 || distAlong > handLength) return false;
  float perpDist = abs(mx * hy - my * hx);
  return perpDist <= 10;
}

void mousePressed() {
  if (isMouseOverHand(currentHourAngle, clockRadius * 0.5f)) {
    grabbingHourHand = true;
    grabbedHourAngle = currentHourAngle;
  }
}

void mouseDragged() {
  if (!grabbingHourHand) return;
  float dx = mouseX - width / 2;
  float dy = mouseY - height / 2;
  float angle = degrees(atan2(dy, dx)) + 90;
  if (angle < 0) angle += 360;
  grabbedHourAngle = angle;
  if (!hasMoved || millis() - lastDialStartPlayTime > dialStartCooldown) {
    dialStartPlayer.rewind();
    dialStartPlayer.play();
    lastDialStartPlayTime = millis();
    hasMoved = true;
  }
}

void mouseReleased() {
  if (!grabbingHourHand) return;
  grabbingHourHand = false;
  float snappedAngle = round(grabbedHourAngle / 30) * 30 % 360;
  snappedAngleAfterRelease = snappedAngle;
  currentHourAngle = snappedAngle;
  targetHourAngle = currentHourAngle;
  waitingBeforeReturn = true;
  hourHandReleaseTime = millis();
  hasMoved = false;
  int hourFromAngle = (int)(snappedAngle / 30);

  for (int i = 0; i < hours.length; i++) {
    if (hours[i] == hourFromAngle) {
      isCall = true;
      callPlayScheduled = true;
      callPlayTime = millis() + 3200;
      getWeatherForCity(cities[i]);
      break;
    }
  }
  
  int currentHour = (int)(currentHourAngle / 30) % 12;
  
  for (int i = 0; i < hours.length; i++) {
    if (hours[i] == currentHour) {
      matchedCity = cities[i];
      break;
    }
  }
}

void getWeatherForCity(String city) {
  String apiKey = "***";
  String url = "https://api.openweathermap.org/data/2.5/weather?q=" + city + "&appid=" + apiKey + "&units=metric&lang=en";
  JSONObject weatherData = loadJSONObject(url);
  if (weatherData == null) {
    return;
  }
  JSONArray weatherArray = weatherData.getJSONArray("weather");
  JSONObject weather = weatherArray.getJSONObject(0);
  weatherType = weather.getString("main");
}

void secondHand(color c) {
  stroke(c);
  strokeWeight(3);
  line(0, clockRadius * 0.1f, 0, -clockRadius * 0.8f);
}


void minuteHand(color c) {
  stroke(c);
  strokeWeight(6);
  line(0, clockRadius * 0.1f, 0, -clockRadius * 0.7f);
}

void hourHand(color c) {
  stroke(c);
  strokeWeight(10);
  line(0, clockRadius * 0.1f, 0, -clockRadius * 0.5f);
}

void clockFace() {
  float theta = 0;
  float tickLength;

  noStroke();
  rectMode(CENTER);
  fill(245);
  rect(0, 0, clockRadius * 2, clockRadius * 2);

  noFill();
  strokeWeight(8);
  float s = clockRadius * 1.96;
  float half = s / 2;

  stroke(220);
  line(-half, -half, half, -half);
  stroke(240);
  line(-half, half, half, half);

  fill(50);
  textSize(24);
  text(matchedCity, 0, -clockRadius / 3);

  stroke(50);
  while (theta < 360) {
    if (theta % 30 == 0) {
      tickLength = 7;
      strokeWeight(5);
    } else {
      tickLength = 7;
      strokeWeight(1);
    }
    float tickStartOffset = 15;
    float x1 = (clockRadius - tickStartOffset) * cos(radians(theta));
    float y1 = (clockRadius - tickStartOffset) * sin(radians(theta));
    float x2 = (clockRadius - tickStartOffset - tickLength) * cos(radians(theta));
    float y2 = (clockRadius - tickStartOffset - tickLength) * sin(radians(theta));
    line(x1, y1, x2, y2);
    theta += 6;
  }

  PFont font = createFont("NormalidadCompact-Medium.ttf", 1);
  textFont(font);

  fill(50);
  float d = clockRadius * 0.7;
  textSize(clockRadius * 0.28);
  for (int i = 1; i <= 12; i++) {
    float angle = radians(30 * i);
    float x = d * sin(angle);
    float y = -d * cos(angle);
    text(i, x, y - 6);
  }
}

class FadeImage {
  PImage img;
  float alpha;
  int fadeInTime;
  int holdTime;
  int fadeOutTime;
  int totalTime;
  int startTime;
  boolean finished = false;
  int delay; 

  FadeImage(String filename, int fadeIn, int hold, int fadeOut, int delayMillis) {
    img = loadImage(filename);
    fadeInTime = fadeIn;
    holdTime = hold;
    fadeOutTime = fadeOut;
    delay = delayMillis;
    totalTime = fadeIn + hold + fadeOut;
    startTime = millis();
  }

  void update() {
    int elapsed = millis() - startTime - delay;

    if (elapsed < 0) {
      alpha = 0;
      return;
    }

    if (elapsed < fadeInTime) {
      alpha = map(elapsed, 0, fadeInTime, 0, 150);
    } else if (elapsed < fadeInTime + holdTime) {
      alpha = 150;
    } else if (elapsed < totalTime) {
      int fadeOutElapsed = elapsed - fadeInTime - holdTime;
      alpha = map(fadeOutElapsed, 0, fadeOutTime, 150, 0);
    } else {
      alpha = 0;
      finished = true;
      images = null;
    }
  }

  void display() {
    if (!finished && img != null) {
      tint(255, alpha);
      image(img, 0, 0);
      noTint();  // 他の描画に影響しないようリセットできるらしい?
    }
  }
}
