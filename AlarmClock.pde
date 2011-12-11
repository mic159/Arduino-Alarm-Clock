#include <SPI.h>
#include <RTClib.h>
#include <RTC_DS3234.h>
#include <SerialDisplay.h>
#include "pitches.h"

const int cs_clock = 9; //DeadOn RTC
const int cs_display = 10; //7-segment display
const int display_power = 8;
const int buzzer = 5;
const int button_1 = 2;
const int button_2 = 3; // Main button, interrupt 1
const int button_3 = 4;

RTC_DS3234 RTC(cs_clock);
SerialDisplay disp(cs_display);

enum MODE
{
  MODE_NORMAL,
  MODE_SECONDS,
  MODE_MELODY,
  MODE_MESSAGE,
  MODE_SETTINGS,
};

MODE state;
byte brightness = 100;

const int melody[] = {NOTE_C4, NOTE_G3,NOTE_G3, NOTE_A3, NOTE_G3, 0, NOTE_B3, NOTE_C4};
// note durations: 4 = quarter note, 8 = eighth note, etc.:
const int noteDurations[] = { 4, 8, 8, 4, 4, 4, 4, 4 };

void setup()
{
  state = MODE_NORMAL;
  pinMode(buzzer, OUTPUT);
  pinMode(display_power, OUTPUT);
  pinMode(button_1, INPUT);
  pinMode(button_2, INPUT);
  pinMode(button_3, INPUT);

  SPI.begin();
  RTC.begin();
  //Serial.begin(19200);
  if (!RTC.isrunning())
  {
    RTC.adjust(DateTime(__DATE__, __TIME__));
  }

  digitalWrite(display_power, HIGH);
  delay(200);
  disp.begin();
  disp.setBrightness(brightness); // Set brightness

  attachInterrupt(1, handle_main_button, RISING);
  attachInterrupt(0, handle_second_button, RISING);
}

void loop()
{
  if (state == MODE_NORMAL)
  {
    DateTime now = RTC.now();

    int hour = now.hour() % 12;
    if (hour == 0) hour = 12;
    disp.writeNumbers(hour, now.minute(), false);

    bool am_pm = now.hour() > 12;
    disp.writeSpecial(true, false, false, false, am_pm, false);

    delay (500);
  }
  else if (state == MODE_SECONDS)
  {
    DateTime now = RTC.now();
    disp.writeNumbers(now.second());
    disp.writeSpecial(); // Clear dots
    
    delay (250);
  }
  else if (state == MODE_MELODY)
  {
    disp.writeSpecial(); // Clear dots
    for (int thisNote = 0; thisNote < 8; thisNote++) {
      disp.writeNumbers(thisNote);

      // to calculate the note duration, take one second 
      // divided by the note type.
      //e.g. quarter note = 1000 / 4, eighth note = 1000/8, etc.
      int noteDuration = 1000/noteDurations[thisNote];
      tone(buzzer, melody[thisNote],noteDuration);

      // to distinguish the notes, set a minimum time between them.
      // the note's duration + 30% seems to work well:
      int pauseBetweenNotes = noteDuration * 1.30;
      delay(pauseBetweenNotes);
      // stop the tone playing:
      noTone(buzzer);
    }
    state = MODE_NORMAL;
  }
  else if (state == MODE_MESSAGE)
  {
    static const char* message = "HIxtHerexxx";
    static int length = 11;
    static int pos = 0;
    int c1, c2, c3, c4;
    c1 = message[(pos)   % length];
    c2 = message[(pos+1) % length];
    c3 = message[(pos+2) % length];
    c4 = message[(pos+3) % length];
    disp.writeNumbers(c1, c2, c3, c4);
    pos = (pos + 1) % length;
    delay(500);
  }
  else if (state == MODE_SETTINGS)
  {
    disp.writeNumbers(brightness);
    disp.setBrightness(brightness);
    delay(100);
  }
}

void handle_main_button()
{
  static long lastDebounceTime = 0;
  if ((millis() - lastDebounceTime) < 1000)
  {
    return;
  }
  lastDebounceTime = millis();
  
  if (state != MODE_SETTINGS)
  {
    state = MODE_MELODY;
  }
  else if (state == MODE_SETTINGS)
  {
    brightness += 20;
  }
}

void handle_second_button()
{
  static long lastDebounceTime = 0;
  if ((millis() - lastDebounceTime) < 300)
  {
    return;
  }
  lastDebounceTime = millis();
  switch (state) 
  {
    case MODE_NORMAL:
      state = MODE_SECONDS;
      break;
    case MODE_SECONDS:
      state = MODE_MESSAGE;
      break;
    case MODE_MESSAGE:
      state = MODE_SETTINGS;
      break;
    default:
      state = MODE_NORMAL;
      break;
  }
}

