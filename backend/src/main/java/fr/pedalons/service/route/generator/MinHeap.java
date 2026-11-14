package fr.pedalons.service.route.generator;

import java.util.Arrays;

/** Binary heap of (double key, int value) on primitive arrays; ties are broken by smaller value. */
final class MinHeap {
  private double[] keys = new double[64];
  private int[] vals = new int[64];
  private int size;
  private double poppedKey;

  boolean isEmpty() {
    return size == 0;
  }

  void clear() {
    size = 0;
  }

  /** Key of the entry returned by the last {@link #pop()}. */
  double poppedKey() {
    return poppedKey;
  }

  void push(double key, int value) {
    if (size == keys.length) {
      keys = Arrays.copyOf(keys, size * 2);
      vals = Arrays.copyOf(vals, size * 2);
    }
    int i = size++;
    while (i > 0) {
      int parent = (i - 1) >>> 1;
      if (less(key, value, keys[parent], vals[parent])) {
        keys[i] = keys[parent];
        vals[i] = vals[parent];
        i = parent;
      } else {
        break;
      }
    }
    keys[i] = key;
    vals[i] = value;
  }

  int pop() {
    int result = vals[0];
    poppedKey = keys[0];
    size--;
    if (size > 0) {
      double key = keys[size];
      int value = vals[size];
      int i = 0;
      while (true) {
        int child = 2 * i + 1;
        if (child >= size) {
          break;
        }
        if (child + 1 < size && less(keys[child + 1], vals[child + 1], keys[child], vals[child])) {
          child++;
        }
        if (less(keys[child], vals[child], key, value)) {
          keys[i] = keys[child];
          vals[i] = vals[child];
          i = child;
        } else {
          break;
        }
      }
      keys[i] = key;
      vals[i] = value;
    }
    return result;
  }

  private static boolean less(double k1, int v1, double k2, int v2) {
    return k1 < k2 || (k1 == k2 && v1 < v2);
  }
}
