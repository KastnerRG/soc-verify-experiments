import numpy as np
import argparse

def main(B, I, O, DIR):
    # Write batch, input, and output sizes to params.h
    with open(f"{DIR}/params.h", "w") as f:
        f.write(f"#define B {B}\n")
        f.write(f"#define I {I}\n")
        f.write(f"#define O {O}\n")

    # Weights sits on-chip, no need generate
    # Generate random matrices
    # For now, don't care about correctness of rtl inference of hls4ml.
    x = np.random.randint(-32768, 32767, size=(B, I), dtype=np.int32)
    
    # Concatenate matrices
    with open(f"{DIR}/x.bin", "wb") as f:
        f.write(x.astype(np.int16 ).tobytes())

    # Not writing y, for now, should include this in hls4ml project

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate matrices and perform matrix operations.")
    parser.add_argument("--B", type=int, required=True, help="Batch size")
    parser.add_argument("--I", type=int, required=True, help="Input size")
    parser.add_argument("--O", type=int, required=True, help="Output size")
    parser.add_argument("--DIR", type=str, required=True, help="Full directory path to save matrices")
    args = parser.parse_args()
    
    main(args.B, args.I, args.O, args.DIR)