#include <SoftwareSerial.h>
#include <AFMotor.h>

// ----------------- DC Motors -----------------
AF_DCMotor motor1(1, MOTOR12_1KHZ); // Front Left
AF_DCMotor motor2(2, MOTOR12_1KHZ); // Front Right
AF_DCMotor motor3(3, MOTOR34_1KHZ); // Back Left
AF_DCMotor motor4(4, MOTOR34_1KHZ); // Back Right
int motorSpeed = 150;

SoftwareSerial bluetooth(A0, A1); // RX, TX

void setup() {
  Serial.begin(9600);
  bluetooth.begin(9600); 
  Serial.println("Ready");
}

void loop() {
  if (bluetooth.available() > 0) {
    char command = bluetooth.read();
    Serial.println(command);
    switch (command) {
      case 'F': moveForward(); break;
      case 'B': moveBackward(); break;
      case 'L': moveLeft(); break;
      case 'R': moveRight(); break;
      case 'J': topLeft(); break;
      case 'K': bottomRight(); break;
      case 'M': bottomLeft(); break;
      case 'I': topRight(); break;
      case 'T': stopMotors(); break;
      // case 'S': startStepper(true, 200, 1000); break;   // CW
      // case 's': startStepper(false, 200, 1000); break;  // CCW
    }
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
