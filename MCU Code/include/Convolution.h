#ifndef CONVOLUTION_H
#define CONVOLUTION_H

#include <Arduino.h>

// Define standard lengths based on your requirements
#define INPUT_LEN 400
#define RESULT_LEN (INPUT_LEN * 2 - 1) // 799 for length 400 inputs

class SignalProcessor {
  public:
    // Buffer to store the result
    // We make this public so you can access it directly if needed
    float result[RESULT_LEN]; 

    // Constructor
    SignalProcessor() {
       // Optional: Initialize result array to 0
       memset(result, 0, sizeof(result));
    }

    // Function to perform convolution on two inputs
    void performConvolution(const float* signalA, const float* signalB) {
      // Clear previous results
      memset(result, 0, sizeof(result));

      // Perform convolution
      // O(N^2) complexity
      for (int i = 0; i < RESULT_LEN; i++) {
        float sum = 0;
        for (int j = 0; j < INPUT_LEN; j++) {
          // Check bounds to ensure we are overlapping valid parts of the arrays
          if ((i - j) >= 0 && (i - j) < INPUT_LEN) {
            sum += signalA[j] * signalB[i - j];
          }
        }
        result[i] = sum;
      }
    }

    // Helper to print the result array
    void printResult() {
      Serial.println("--- Convolution Result ---");
      for (int i = 0; i < RESULT_LEN; i++) {
        Serial.print(result[i], 4); // Print with 4 decimal places
        Serial.print(",\t");
        if ((i + 1) % 10 == 0) Serial.println(); // Newline every 10 items
      }
      Serial.println("\n--------------------------");
    }

    // Find the maximum value in the result array
    float getMax() {
      float maxValue = result[0];
      for (int i = 1; i < RESULT_LEN; i++) {
        if (result[i] > maxValue) {
          maxValue = result[i];
        }
      }
      return maxValue;
    }

    // Find the maximum absolute correlation value
    float getMaxAbs() {
      float maxValue = 0;
      for (int i = 0; i < RESULT_LEN; i++) {
        if (abs(result[i]) > maxValue) {
          maxValue = abs(result[i]);
        }
      }
      return maxValue;
    }

    // Find the index of the maximum absolute value
    int getMaxIndex() {
      float maxValue = 0;
      int maxIndex = 0;
      for (int i = 0; i < RESULT_LEN; i++) {
        if (abs(result[i]) > maxValue) {
          maxValue = abs(result[i]);
          maxIndex = i;
        }
      }
      return maxIndex;
    }
};

#endif