import { ethers, upgrades } from "hardhat";

async function main() {
  const lzContracts = {
    metisAndromeda: "0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4",
    metisGoerli: '0xae92d5aD7583AD66E49A0c67BAd18F6ba52dDDc1',
    optimism: "0x3c2269811836af69497E5F486A85D7316753cf62",
    polygon: "0x3c2269811836af69497E5F486A85D7316753cf62",
  };

  const VastToken = await ethers.getContractFactory("VastToken");
  const vastToken = await upgrades.deployProxy(
    VastToken,
    ["TEST Token", "TEST", lzContracts.metisGoerli],
    {
      kind: "uups",
    }
  );
  console.log("VastToken contract deployed to address:", vastToken.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
