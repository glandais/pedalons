package fr.pedalons.service.route.generator;

import java.util.Arrays;

/** Growable primitive int list. */
final class IntList {
  private int[] data;
  private int size;

  IntList() {
    this(8);
  }

  IntList(int capacity) {
    data = new int[Math.max(capacity, 4)];
  }

  void add(int v) {
    if (size == data.length) {
      data = Arrays.copyOf(data, size * 2);
    }
    data[size++] = v;
  }

  int get(int i) {
    return data[i];
  }

  void set(int i, int v) {
    data[i] = v;
  }

  int size() {
    return size;
  }

  boolean isEmpty() {
    return size == 0;
  }

  void clear() {
    size = 0;
  }

  int last() {
    return data[size - 1];
  }

  int removeLast() {
    return data[--size];
  }

  boolean contains(int v) {
    for (int i = 0; i < size; i++) {
      if (data[i] == v) {
        return true;
      }
    }
    return false;
  }

  /** Removes the first occurrence of {@code v}; order of the others is kept. */
  void remove(int v) {
    for (int i = 0; i < size; i++) {
      if (data[i] == v) {
        System.arraycopy(data, i + 1, data, i, size - i - 1);
        size--;
        return;
      }
    }
  }

  void replace(int oldValue, int newValue) {
    for (int i = 0; i < size; i++) {
      if (data[i] == oldValue) {
        data[i] = newValue;
        return;
      }
    }
  }

  int[] toArray() {
    return Arrays.copyOf(data, size);
  }
}
