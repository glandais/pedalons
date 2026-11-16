package fr.pedalons.infrastructure.routedetails;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.function.BooleanSupplier;

/**
 * The bounded pipe between the thread that reads a team's tracks and the HTTP client that sends
 * them (lot 3b plan §6.3): 16 blocks of 64 KiB, so 1 MiB in flight whatever the size of the team.
 * Written by the job's thread, read by the HTTP client's.
 *
 * <p>The writer waits at most a second for a free block, and each time looks whether the service
 * has already answered or the deadline has passed: then it stops with {@link
 * PipeStoppedException} and {@link #stopped()} is true, the response decides. The JDK client
 * exposes a response sent during the body only when the server closes the connection; the gateway
 * relies on {@code Expect: 100-continue} for early refusals. A reader that closes early stops the
 * writer the same way.
 */
final class DepositBodyPipe {

  static final int BLOCK_BYTES = 64 * 1024;
  static final int BLOCKS = 16;

  private static final byte[] EOF = new byte[0];

  /** The writer was told to stop: the service answered, the deadline passed or the reader left. */
  static final class PipeStoppedException extends IOException {
    PipeStoppedException(String message) {
      super(message);
    }
  }

  private final ArrayBlockingQueue<byte[]> queue = new ArrayBlockingQueue<>(BLOCKS);
  private final BooleanSupplier responded;
  private final long deadlineNanos;
  private volatile boolean stopped;
  private volatile boolean failed;
  private volatile boolean readerClosed;

  /**
   * @param responded true once the service has answered
   * @param deadlineNanos {@code System.nanoTime()} past which the writer stops
   */
  DepositBodyPipe(BooleanSupplier responded, long deadlineNanos) {
    this.responded = responded;
    this.deadlineNanos = deadlineNanos;
  }

  /** Whether the writer was stopped by the pipe (and not by a failure of its own). */
  boolean stopped() {
    return stopped;
  }

  /** The writer failed: the reader gets an {@link IOException} and the request ends. */
  void fail() {
    failed = true;
  }

  /** The writer's side. {@code close()} ends the body. */
  OutputStream writer() {
    return new OutputStream() {
      private byte[] buffer = new byte[BLOCK_BYTES];
      private int position;
      private boolean closed;

      @Override
      public void write(int b) throws IOException {
        if (position == buffer.length) {
          flushBlock();
        }
        buffer[position++] = (byte) b;
      }

      @Override
      public void write(byte[] b, int off, int len) throws IOException {
        int offset = off;
        int left = len;
        while (left > 0) {
          if (position == buffer.length) {
            flushBlock();
          }
          int n = Math.min(left, buffer.length - position);
          System.arraycopy(b, offset, buffer, position, n);
          position += n;
          offset += n;
          left -= n;
        }
      }

      private void flushBlock() throws IOException {
        if (position == 0) {
          return;
        }
        byte[] block =
            position == buffer.length ? buffer : java.util.Arrays.copyOf(buffer, position);
        offer(block);
        buffer = new byte[BLOCK_BYTES];
        position = 0;
      }

      @Override
      public void close() throws IOException {
        if (closed) {
          return;
        }
        closed = true;
        flushBlock();
        offer(EOF);
      }
    };
  }

  private void offer(byte[] block) throws IOException {
    try {
      while (!queue.offer(block, 1, TimeUnit.SECONDS)) {
        stopIfNeeded();
      }
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      stopped = true;
      throw new PipeStoppedException("interrupted");
    }
    if (readerClosed) {
      stopped = true;
      throw new PipeStoppedException("reader closed");
    }
  }

  private void stopIfNeeded() throws PipeStoppedException {
    if (readerClosed || responded.getAsBoolean() || System.nanoTime() - deadlineNanos >= 0) {
      stopped = true;
      throw new PipeStoppedException("deposit stopped");
    }
  }

  /** The reader's side, for {@code BodyPublishers.ofInputStream}. */
  InputStream reader() {
    return new InputStream() {
      private byte[] current = new byte[0];
      private int position;
      private boolean eof;

      @Override
      public int read() throws IOException {
        byte[] one = new byte[1];
        int n = read(one, 0, 1);
        return n < 0 ? -1 : one[0] & 0xff;
      }

      @Override
      public int read(byte[] b, int off, int len) throws IOException {
        if (len == 0) {
          return 0;
        }
        while (position >= current.length) {
          if (eof) {
            return -1;
          }
          byte[] next;
          try {
            next = queue.poll(1, TimeUnit.SECONDS);
          } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IOException("interrupted");
          }
          if (next == null) {
            if (failed || stopped) {
              throw new IOException("deposit body abandoned");
            }
            continue;
          }
          if (next == EOF) {
            eof = true;
            return -1;
          }
          current = next;
          position = 0;
        }
        int n = Math.min(len, current.length - position);
        System.arraycopy(current, position, b, off, n);
        position += n;
        return n;
      }

      @Override
      public void close() {
        readerClosed = true;
      }
    };
  }
}
