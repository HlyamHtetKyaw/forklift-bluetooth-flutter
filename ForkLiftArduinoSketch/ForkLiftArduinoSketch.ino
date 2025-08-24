#include <SoftwareSerial.h>
#include <AFMotor.h>
#include <HX711_ADC.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <AccelStepper.h>

// ---------------- Pins ----------------
#define STEP_PIN 2
#define DIR_PIN 3
#define BT_RX A0   // Arduino RX (Bluetooth TX)
#define BT_TX A1   // Arduino TX (Bluetooth RX)

// HX711 pins
#define LOADCELL_DOUT_PIN 6
#define LOADCELL_SCK_PIN 7

// ---------------- Modules ----------------
HX711_ADC LoadCell(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);
LiquidCrystal_I2C lcd(0x27, 16, 2); // Adjust I2C address if needed
AccelStepper stepper(AccelStepper::DRIVER, STEP_PIN, DIR_PIN);
SoftwareSerial BT(BT_RX, BT_TX); // RX, TX

// ---------------- Settings ----------------
const long MAX_SPEED = 800;   // steps/sec
const long ACCEL = 400;       // steps/sec^2
const long RUN_SPEED = 500;   // speed when running (steps/sec)
const float MAX_WEIGHT = 500.0; // g safety limit
const float HYSTERESIS = 0.9;   // 90% threshold to clear overweight

// ---------------- State ----------------
enum Mode { STOPPED, CW, CCW, LOWERING };
Mode mode = STOPPED;

unsigned long lastLCD = 0;  // timer for LCD refresh
float smoothWeight = 0;     // filtered weight

// ----------------- DC Motors -----------------
AF_DCMotor motor1(1, MOTOR12_1KHZ); // Front Left
AF_DCMotor motor2(2, MOTOR12_1KHZ); // Front Right
AF_DCMotor motor3(3, MOTOR34_1KHZ); // Back Left
AF_DCMotor motor4(4, MOTOR34_1KHZ); // Back Right
int motorSpeed = 150;

unsigned long lastCommandTime = 0;
unsigned long commandTimeout = 100;
bool isMoving = false;

void setup() {
   // Stepper setup
  stepper.setMaxSpeed(MAX_SPEED);
  stepper.setAcceleration(ACCEL);
  stepper.setPinsInverted(true, false, true); // active-low wiring (TB6600)
  stepper.enableOutputs();

  Serial.begin(9600);
  BT.begin(9600); 
  Serial.println("Ready");

    // HX711 setup
  LoadCell.begin();
  LoadCell.start(2000); // wait for loadcell to stabilize
  LoadCell.setCalFactor(100.0); // adjust based on calibration
  LoadCell.tare(); // auto-zero at startup

  // LCD setup
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("System Ready");
  delay(1000);
  lcd.clear();
}

void loop() {
  // ---------------- Stepper must always run ----------------
  if (mode == CW || mode == CCW) {
    stepper.runSpeed();
  } 
  else if (mode == LOWERING) {
    if (stepper.distanceToGo() != 0) {
      stepper.run();  // smooth move down
    } else {
      stopStepper();
    }
  }

  // ---------------- HX711 Weight ----------------
  LoadCell.update();
  float rawWeight = LoadCell.getData();
  smoothWeight = 0.9 * smoothWeight + 0.1 * rawWeight; // simple low-pass filter

  // ---------------- Overweight Protection with Hysteresis ----------------
  if (smoothWeight > MAX_WEIGHT && mode != LOWERING) {
    mode = LOWERING;
    stepper.move(-400); // move down smoothly
    lcd.setCursor(0, 1);
    lcd.print("OVERWEIGHT!    ");
  } 
  else if (smoothWeight < MAX_WEIGHT * HYSTERESIS && mode == LOWERING && stepper.distanceToGo() == 0) {
    stopStepper();
  }

  if (BT.available() > 0) {
    char command = BT.read();
    Serial.println(command);
    lastCommandTime = millis();
    isMoving = true;
    switch (command) {
      case 'F': moveForward(); break;
      case 'B': moveBackward(); break;
      case 'L': moveLeft(); break;
      case 'R': moveRight(); break;
      case 'J': topLeft(); break;
      case 'K': bottomRight(); break;
      case 'M': bottomLeft(); break;
      case 'I': topRight(); break;
      case 'T': stopMotors(); isMoving = false; break;
      case 'A': startStepperCW();break;
      case 'C': startStepperCCW();break;
      case 'P': stopStepper();break;
    }
  }

  if (isMoving && millis() - lastCommandTime > commandTimeout) {
    stopMotors();
    stopStepper();
    isMoving = false;
  }

  // ---------------- LCD Refresh (every 300 ms) ----------------
  if (millis() - lastLCD > 300) {
    lcd.setCursor(0, 0);
    lcd.print("Weight[g]: ");
    lcd.print(smoothWeight, 1); // show 1 decimal
    lcd.print("        ");      // clear old digits
    // Send to Bluetooth as "W:123.4"
    BT.print("W:");
    BT.println(smoothWeight, 1); // send 1 decimal place
    lastLCD = millis();
  }

}

void moveForward(){
  motor1.setSpeed(motorSpeed);
  motor2.setSpeed(motorSpeed);
  motor3.setSpeed(motorSpeed);
  motor4.setSpeed(motorSpeed);
  motor1.run(FORWARD);
  motor2.run(FORWARD);
  motor3.run(FORWARD);
  motor4.run(FORWARD);
}
void moveBackward(){
  motor1.setSpeed(motorSpeed);
  motor2.setSpeed(motorSpeed);
  motor3.setSpeed(motorSpeed);
  motor4.setSpeed(motorSpeed);
  motor1.run(BACKWARD);
  motor2.run(BACKWARD);
  motor3.run(BACKWARD);
  motor4.run(BACKWARD);
}
void moveLeft(){ 
  motor1.setSpeed(motorSpeed); 
  motor2.setSpeed(motorSpeed);
  motor3.setSpeed(motorSpeed);
  motor4.setSpeed(motorSpeed);
  motor1.run(BACKWARD); 
  motor2.run(FORWARD); 
  motor3.run(FORWARD); 
  motor4.run(BACKWARD); 
}
void moveRight(){ 
  motor1.setSpeed(motorSpeed); 
  motor2.setSpeed(motorSpeed); 
  motor3.setSpeed(motorSpeed); 
  motor4.setSpeed(motorSpeed);
  motor1.run(FORWARD); 
  motor2.run(BACKWARD); 
  motor3.run(BACKWARD); 
  motor4.run(FORWARD); 
}
void topLeft(){
  motor1.setSpeed(motorSpeed);
  motor1.run(FORWARD);
  motor3.setSpeed(motorSpeed);
  motor3.run(FORWARD);
}
void topRight(){
  motor2.setSpeed(motorSpeed);
  motor2.run(BACKWARD);
  motor4.setSpeed(motorSpeed);
  motor4.run(BACKWARD);
}
void bottomLeft(){
  motor2.setSpeed(motorSpeed);
  motor2.run(FORWARD);
  motor4.setSpeed(motorSpeed);
  motor4.run(FORWARD);
}
void bottomRight(){
  motor1.setSpeed(motorSpeed);
  motor1.run(BACKWARD);
  motor3.setSpeed(motorSpeed);
  motor3.run(BACKWARD);
}
void stopMotors(){
  motor1.run(RELEASE);
  motor2.run(RELEASE);
  motor3.run(RELEASE);
  motor4.run(RELEASE);
}
void startStepperCW() {
  mode = CW;
  stepper.setSpeed(RUN_SPEED);
  lcd.setCursor(0, 1);
  lcd.print("Motor: CW      ");
}

void startStepperCCW() {
  mode = CCW;
  stepper.setSpeed(-RUN_SPEED);
  lcd.setCursor(0, 1);
  lcd.print("Motor: CCW     ");
}

void stopStepper() {
  mode = STOPPED;
  stepper.setSpeed(0);
  lcd.setCursor(0, 1);
  lcd.print("Motor: STOP    ");
}

