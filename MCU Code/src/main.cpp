#include <Arduino.h>
#include <arm_math.h> 
#define DATA_LEN 400  
#define Fs 400000.0   // 400kHz
const float c = 343.0f;       // Speed of sound (m/s)
const float d = 0.05f;
const float RadianToDeg = 180.0f / PI; // Radians to degree
float convResult[799];
int maxIndex = 0;
float maxValue = 0;
int resultLength = 0;

float32_t array1[DATA_LEN];
float32_t array2[DATA_LEN];

void performCorrelation() {
  uint32_t n = DATA_LEN;         // 400
  uint32_t resultSize = 2 * n - 1; // 799
  resultLength = resultSize; 

  // Computes the correlation of array1 and array2 and stores it in convResult
  arm_correlate_f32(array1, n, array2, n, convResult);

  // Finds the maximum value and its index in the result array
  float32_t maxVal;
  uint32_t maxIndexUint;
  arm_max_f32(convResult, resultSize, &maxVal, &maxIndexUint);

  maxIndex = (int)maxIndexUint;
  maxValue = maxVal;

  // Angle Calculation
  int lagSamples = maxIndex - (n - 1);
  
  float timeDelaySeconds = lagSamples * (1.0f / Fs);
  float arg = (timeDelaySeconds * c) / d;

  // Clamp argument to [-1, 1] domain for asin
  if (arg > 1.0f) arg = 1.0f;
  if (arg < -1.0f) arg = -1.0f;

  float timeDelayMicros = timeDelaySeconds * 1000000.0f;
  float sourceAngle = -asinf(arg);
  float angleDegrees = sourceAngle * RadianToDeg;

  Serial.print("Time Delay: ");
  Serial.print(timeDelayMicros);
  Serial.println(" us");

  Serial.print("Source Angle: ");
  Serial.print(angleDegrees, 1);
  Serial.println(" degrees");
}
void printArray(const char* label, float* arr, int size) {
  Serial.print(label); 
  Serial.println("_START"); // Marker: "SIG1_DATA_START"
  
  for (int i = 0; i < size; i++) {
    Serial.print(arr[i], 4);
    if (i < size - 1) Serial.print(",");
  }
  Serial.println();
  
  Serial.print(label);
  Serial.println("_END"); // Marker: "SIG1_DATA_END"
}

void setup() {
  Serial.begin(115200);
  while (!Serial) {};
}
void loop() {
  if (Serial.available() >= 802){
    byte h1 = Serial.read();
    byte h2 = Serial.peek();
      
    if (h1 == 255 && h2 == 255) {
      Serial.read(); // Consume 2nd header byte
      
      // Read Data
      for (int i = 0; i < DATA_LEN; i++) {
        array1[i] = (float)((int8_t)Serial.read()); 
      }
      for (int i = 0; i < DATA_LEN; i++) {
        array2[i] = (float)((int8_t)Serial.read());
      }
    }

  float start = micros();
  performCorrelation();
  float end = micros();

  Serial.print("Time = ");
  Serial.println(end-start);
  Serial.println(resultLength);
    // Send Everything Back to MATLAB
      printArray("SIG1_DATA", array1, DATA_LEN);
      printArray("SIG2_DATA", array2, DATA_LEN);
      printArray("CORR_DATA", convResult, resultLength);
  }
  else {
    delay(1000);
  }
}

