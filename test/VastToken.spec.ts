import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";

import { VastToken } from "../typechain";

describe("VastToken", function () {
  this.timeout(0);

  let contractOwner: SignerWithAddress;
  let contractAdmin: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let tokenContract1: VastToken;
  let tokenContract2: VastToken;

  const chainId1 = 123;
  const chainId2 = 456;

  beforeEach(async () => {
    [contractOwner, contractAdmin, user1, user2, user3] =
      await ethers.getSigners();

    const LayerZeroEndpointMock1 = await ethers.getContractFactory(
      "LZEndpointMock"
    );
    const lzEndpointMock1 = await LayerZeroEndpointMock1.deploy(chainId1);

    const LayerZeroEndpointMock2 = await ethers.getContractFactory(
      "LZEndpointMock"
    );
    const lzEndpointMock2 = await LayerZeroEndpointMock2.deploy(chainId1);

    const VastToken = await ethers.getContractFactory("VastToken");
    tokenContract1 = (await upgrades.deployProxy(
      VastToken,
      ["TEST", "TEST", lzEndpointMock1.address],
      {
        kind: "uups",
      }
    )) as VastToken;
    tokenContract2 = (await upgrades.deployProxy(
      VastToken,
      ["TEST", "TEST", lzEndpointMock2.address],
      {
        kind: "uups",
      }
    )) as VastToken;

    lzEndpointMock1.setDestLzEndpoint(
      tokenContract2.address,
      lzEndpointMock2.address
    );
    lzEndpointMock2.setDestLzEndpoint(
      tokenContract1.address,
      lzEndpointMock1.address
    );

    tokenContract1.setTrustedRemote(
      chainId2,
      ethers.utils.solidityPack(
        ["address", "address"],
        [tokenContract2.address, tokenContract1.address]
      )
    );
    tokenContract2.setTrustedRemote(
      chainId1,
      ethers.utils.solidityPack(
        ["address", "address"],
        [tokenContract1.address, tokenContract2.address]
      )
    );
  });

  describe("award", () => {
    it("should fail to award points as user", async () => {
      const transaction = tokenContract1
        .connect(user1)
        .award(user1.address, 10);
      await expect(transaction).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );
    });

    it("should fail to award points as admin", async () => {
      const transaction = tokenContract1
        .connect(contractAdmin)
        .award(user1.address, 10);
      await expect(transaction).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );
    });

    it("should award 10 points to user1 as owner", async () => {
      await tokenContract1.award(user1.address, 10);
      await expect(await tokenContract1.balanceOf(user1.address)).to.equal(10);
    });
  });

  describe("awardMany", () => {
    it("should fail to award many points as user", async () => {
      const transaction = tokenContract1
        .connect(user1)
        .awardMany([user1.address, user2.address], [10, 20]);
      await expect(transaction).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );
    });

    it("should fail to award many points as admin", async () => {
      const transaction = tokenContract1
        .connect(contractAdmin)
        .awardMany([user1.address, user2.address], [10, 20]);
      await expect(transaction).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );
    });

    it("should award many points to user1 as owner", async () => {
      await tokenContract1.awardMany([user1.address, user2.address], [10, 20]);
      await expect(await tokenContract1.balanceOf(user1.address)).to.equal(10);
      await expect(await tokenContract1.balanceOf(user2.address)).to.equal(20);
    });
  });

  describe("redeem", () => {
    it("should fail to redeem points as contract owner (not contract admin)", async () => {
      await tokenContract1.award(user1.address, 10);
      const transaction = tokenContract1
        .connect(contractAdmin)
        .redeem(user1.address, 3);
      await expect(transaction).to.be.revertedWith("Caller is not an admin");
    });

    it("should redeem 3 points from user1", async () => {
      await tokenContract1.award(user1.address, 10);
      await tokenContract1.createAdmin(contractAdmin.address);
      await tokenContract1.connect(contractAdmin).redeem(user1.address, 3);
      await expect(await tokenContract1.balanceOf(user1.address)).to.equal(7);
    });
  });

  describe("bridge", () => {
    it("should bridge from tokenContract1 to tokenContract2", async () => {
      await tokenContract1.award(user1.address, 10);
      await tokenContract1
        .connect(user1)
        .bridge(
          user1.address,
          chainId2,
          user1.address,
          4,
          user1.address,
          user1.address,
          [],
          { value: ethers.utils.parseEther("0.5") }
        );

      await expect(await tokenContract1.balanceOf(user1.address)).to.equal(6);
      await expect(await tokenContract2.balanceOf(user1.address)).to.equal(4);
    });
  });

  describe("burn", () => {
    it("should fail to burn more token(s) than owned", async () => {
      await tokenContract1.award(user1.address, 10);
      const transaction = tokenContract1.connect(user1).burn(20);
      await expect(transaction).to.be.revertedWith(
        "ERC20: burn amount exceeds balance"
      );
    });

    it("should allow token holder to burn 0 token(s)", async () => {
      await tokenContract1.award(user1.address, 10);
      await tokenContract1.connect(user1).burn(0);

      await expect(await tokenContract1.balanceOf(user1.address)).to.equal(10);
    });

    it("should allow token holder to burn token(s)", async () => {
      await tokenContract1.award(user1.address, 10);
      await tokenContract1.connect(user1).burn(6);

      await expect(await tokenContract1.balanceOf(user1.address)).to.equal(4);
    });
  });

  describe("soulbound", () => {
    it("should fail to transfer token", async () => {
      await tokenContract1.award(user1.address, 10);
      const transaction = tokenContract1
        .connect(user1)
        .transfer(user2.address, 5);
      await expect(transaction).to.be.revertedWith(
        "Forbidden()"
      );
    });

    it("should fail to approve token", async () => {
      await tokenContract1.award(user1.address, 10);
      const transaction = tokenContract1.transferFrom(
        user1.address,
        user2.address,
        5
      );
      await expect(transaction).to.be.revertedWith(
        "Forbidden()"
      );
    });

    it("should fail to transfer token to another address", async () => {
      await tokenContract1.award(user1.address, 10);
      const transaction = tokenContract1
        .connect(user1)
        .approve(user2.address, 5);
      await expect(transaction).to.be.revertedWith(
        "Forbidden()"
      );
    });

    it("should fail to increase allowance", async () => {
      await tokenContract1.award(user1.address, 10);
      const transaction = tokenContract1
        .connect(user1)
        .increaseAllowance(user2.address, 5);
      await expect(transaction).to.be.revertedWith(
        "Forbidden()"
      );
    });

    it("should fail to decrease allowance", async () => {
      await tokenContract1.award(user1.address, 10);
      const transaction = tokenContract1
        .connect(user1)
        .decreaseAllowance(user2.address, 5);
      await expect(transaction).to.be.revertedWith(
        "Forbidden()"
      );
    });

    it("should have 0 allowance", async () => {
      await tokenContract1.award(user1.address, 10);
      await expect(
        await tokenContract1.allowance(user1.address, user2.address)
      ).to.equal(0);
    });
  });
});
