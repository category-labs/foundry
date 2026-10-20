---
foundry-evm-core: patch
foundry-evm: patch
forge: patch
forge-script: patch
anvil: patch
chisel: patch
---

Use consumed gas for Monad execution reports and isolated calls when receipt gas charges the full transaction limit. Keep gas limits from estimation, broadcast simulation, and access-list creation at or above the calldata validation minimum.
