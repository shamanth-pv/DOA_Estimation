#ifndef SIGNALPROCESSOR_H
#define SIGNALPROCESSOR_H

#include <Arduino.h>

// Updated lengths based on your new code (1ms @ 250kHz = 250 samples)
#define INPUT_LEN 250
#define RESULT_LEN (INPUT_LEN * 2 - 1) // 499

class SignalProcessor {
  public:
    // Buffer to store the result
    float result[RESULT_LEN]; 

    SignalProcessor() {
       memset(result, 0, sizeof(result));
    }

    // REPLACES: arm_correlate_f32
    // Performs Cross-Correlation (Slide and Multiply, No Flip)
    void performCorrelation(const float* signalA, const float* signalB) {
      // Clear previous results
      memset(result, 0, sizeof(result));

      // 1. Loop through every possible shift (lag)
      // i goes from 0 to 498. 
      // i = 249 is "Zero Lag" (Center)
      for (int i = 0; i < RESULT_LEN; i++) {
        float sum = 0;
        int lag = i - (INPUT_LEN - 1); 

        // 2. Multiply and Accumulate
        for (int j = 0; j < INPUT_LEN; j++) {
           int k = j + lag; // Index for signalB
           
           // Check bounds to ensure we are overlapping valid parts
           if (k >= 0 && k < INPUT_LEN) {
             sum += signalA[j] * signalB[k];
           }
        }
        result[i] = sum;
      }
    }

    // REPLACES: arm_max_f32 (Value part)
    float getMaxValue() {
      float maxValue = result[0];
      for (int i = 1; i < RESULT_LEN; i++) {
        if (result[i] > maxValue) {
          maxValue = result[i];
        }
      }
      return maxValue;
    }

    // REPLACES: arm_max_f32 (Index part)
    int getMaxIndex() {
      float maxValue = result[0]; // Start assuming first is max
      int maxIndex = 0;
      
      for (int i = 1; i < RESULT_LEN; i++) {
        if (result[i] > maxValue) {
          maxValue = result[i];
          maxIndex = i;
        }
      }
      return maxIndex;
    }
};

#endif