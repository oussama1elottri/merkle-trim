import hashlib
import json
import os
import glob
import shutil
import subprocess

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

    print(f"[PYTHON] 3 Leaves (Odd) Merkle Root  : 0x{py_root_3}")
    print(f"[PYTHON] 4 Leaves (Even) Merkle Root : 0x{py_root_4}\n")

    # Export test vectors for EVM verification
    test_cases = [
        {
            "name": "Case 1: 3 Leaves (Odd)",
            "commitments": ["0x" + c.hex() for c in leaves_3],
            "expectedRoot": "0x" + py_root_3
        },
        {
            "name": "Case 2: 4 Leaves (Even)",
            "commitments": ["0x" + c.hex() for c in leaves_4],
            "expectedRoot": "0x" + py_root_4
        }
    ]

    hardhat_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "contracts"))
    test_json_path = os.path.join(hardhat_dir, "merkle_parity_test.json")

    with open(test_json_path, "w") as f:
        json.dump(test_cases, f, indent=2)

    # Dynamic environment PATH resolution for npx/node across NVM, Homebrew, and system paths
    nvm_paths = sorted(glob.glob(os.path.expanduser("~/.nvm/versions/node/*/bin")), reverse=True)

    system_paths = ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin", "/bin"]
    all_paths = nvm_paths + system_paths + [os.environ.get("PATH", "")]

    env = os.environ.copy()
    env["PATH"] = ":".join(all_paths)
    env["PARITY_TEST_FILE"] = test_json_path

    npx_bin = os.path.join(nvm_paths[0], "npx") if nvm_paths else "npx"
    cmd = f"{npx_bin} hardhat run scripts/verify-parity.ts"

    try:
        result = subprocess.run(
            cmd,
            cwd=hardhat_dir,
            env=env,
            capture_output=True,
            text=True,
            shell=True
        )



        print("[EVM Verification Output]")
        print(result.stdout)

        if result.returncode == 0 and "[PASS]" in result.stdout:
            print("[SUCCESS] Full Cross-Language Verification Passed!")
            print("Python Merkle root output matches Solidity EVM execution byte-for-byte.")
        else:
            if result.stderr:
                print(result.stderr)
            print("\n[ERROR] Merkle parity verification failed!")
            exit(1)
    finally:
        if os.path.exists(test_json_path):
            os.remove(test_json_path)

if __name__ == "__main__":
    main()
