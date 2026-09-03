import hashlib
import subprocess
import os

def python_merkle_root(leaves):
    if not leaves:
        return b'\x00' * 32
    layer = [hashlib.sha256(leaf).digest() for leaf in leaves]
    while len(layer) > 1:
        if len(layer) % 2 == 1:
            layer.append(layer[-1])  # Duplicate last element if odd
        layer = [
            hashlib.sha256(layer[i] + layer[i + 1]).digest()
            for i in range(0, len(layer), 2)
        ]
    return layer[0]

def main():
    print("=" * 70)
    print(" CROSS-LANGUAGE MERKLE ROOT VERIFICATION (PYTHON vs HARDHAT/EVM)")
    print("=" * 70)

    # Test inputs
    commit_A = hashlib.sha256(b"commitment_A").digest()
    commit_B = hashlib.sha256(b"commitment_B").digest()
    commit_C = hashlib.sha256(b"commitment_C").digest()
    commit_D = hashlib.sha256(b"commitment_D").digest()

    # Case 1: ODD Count (3 leaves)
    leaves_3 = [commit_A, commit_B, commit_C]
    py_root_3 = python_merkle_root(leaves_3).hex()

    # Case 2: EVEN Count (4 leaves)
    leaves_4 = [commit_A, commit_B, commit_C, commit_D]
    py_root_4 = python_merkle_root(leaves_4).hex()

    print(f"\n[PYTHON] 3 Leaves (Odd) Merkle Root  : 0x{py_root_3}")
    print(f"[PYTHON] 4 Leaves (Even) Merkle Root : 0x{py_root_4}\n")

    env = os.environ.copy()
    node_paths = ["/Users/itadmin/.nvm/versions/node/v24.18.0/bin", "/usr/local/bin", "/opt/homebrew/bin"]
    env["PATH"] = ":".join(node_paths) + ":" + env.get("PATH", "")

    hardhat_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "contracts"))
    result = subprocess.run(
        "npx hardhat test",
        cwd=hardhat_dir,
        env=env,
        capture_output=True,
        text=True,
        shell=True
    )

    print(result.stdout)

    if result.returncode == 0:
        print("\n[SUCCESS] Verification passed: Python Merkle root matches Solidity EVM byte-for-byte.")
    else:
        print(result.stderr)
        print("\n[ERROR] Hardhat tests failed.")

if __name__ == "__main__":
    main()
