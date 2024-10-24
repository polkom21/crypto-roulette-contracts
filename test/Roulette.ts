import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import "@nomicfoundation/hardhat-ethers";
import { expect } from "chai";
import hre, { ethers, upgrades } from "hardhat";

enum BetType {
  ZERO, // 0
  DOUBLE_ZERO, // 37 (00)
  STREET,
  ROW,
  BASKET_US,
  SPLIT,
  CORNER,
  DOUBLE_STREET,
  STRAIGHT_UP,
  FIRST_COLUMN,
  SECOND_COLUMN,
  THIRD_COLUMN,
  FIRST_DOZEN,
  SECOND_DOZEN,
  THIRD_DOZEN,
  ONE_TO_EIGHTEEN,
  NINETEEN_TO_THIRTY_SIX,
  EVEN,
  ODD,
  RED,
  BLACK,
}

describe("Roulette", function () {
  async function deployRouletteFixture() {
    const [owner, user] = await hre.ethers.getSigners();
    const TokenFactory = await hre.ethers.getContractFactory("MockToken");
    const token = await TokenFactory.deploy();
    await token.connect(owner).transfer(user.getAddress(), 1_000_000_000);

    const VRFV2WrapperFactory = await hre.ethers.getContractFactory(
      "MockVRFV2PlusWrapper"
    );
    const vrfV2Wrapper = await VRFV2WrapperFactory.deploy();

    const RouletteFactory = await hre.ethers.getContractFactory("Roulette");
    const roulette = await upgrades.deployProxy(RouletteFactory, [
      await token.getAddress(),
      await vrfV2Wrapper.getAddress(),
    ]);
    await roulette.waitForDeployment();
    await token.connect(owner).transfer(roulette.getAddress(), 1_000_000_000);

    await owner.sendTransaction({
      to: roulette.getAddress(),
      value: 1_000_000_000,
    });

    await token.connect(user).approve(roulette.getAddress(), 1_000_000_000);

    return { token, owner, roulette, vrfV2Wrapper, user };
  }

  describe("newBet()", function () {
    describe("zero bet", function () {
      it("with numbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette
            .connect(user)
            .newBet([{ amount: 10, numbers: [1], betType: BetType.ZERO }])
        ).to.be.revertedWith("Numbers not required for this type");
      });

      it("success without won", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette
          .connect(user)
          .newBet([{ amount: 10, numbers: [], betType: BetType.ZERO }]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          5,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore - 10n);
      });

      it("success with won", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette
          .connect(user)
          .newBet([{ amount: 10, numbers: [], betType: BetType.ZERO }]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          0,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 35n);
      });
    });

    describe("double zero bet", function () {
      it("with numbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette
            .connect(user)
            .newBet([
              { amount: 10, numbers: [1], betType: BetType.DOUBLE_ZERO },
            ])
        ).to.be.revertedWith("Numbers not required for this type");
      });

      it("success without won", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette
          .connect(user)
          .newBet([{ amount: 10, numbers: [], betType: BetType.DOUBLE_ZERO }]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          5,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore - 10n);
      });

      it("success with won", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette
          .connect(user)
          .newBet([{ amount: 10, numbers: [], betType: BetType.DOUBLE_ZERO }]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          37,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 35n);
      });
    });

    describe("street bet", function () {
      it("with wrong amount of numbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette
            .connect(user)
            .newBet([{ amount: 10, numbers: [1], betType: BetType.STREET }])
        ).to.be.revertedWith("Invalid numbers length");
      });

      it("with not street numbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette
            .connect(user)
            .newBet([
              { amount: 10, numbers: [1, 2, 4], betType: BetType.STREET },
            ])
        ).to.be.revertedWith("Invalid combination");
      });

      it("street 1,2,3", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette
          .connect(user)
          .newBet([
            { amount: 10, numbers: [1, 2, 3], betType: BetType.STREET },
          ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          5,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore - 10n);
      });

      for (let i = 0; i < 12; i++) {
        it(`street ${i * 3 + 1},${i * 3 + 2},${i * 3 + 3}`, async () => {
          const { roulette, user, vrfV2Wrapper, token } =
            await deployRouletteFixture();
          const balanceBefore = await token.balanceOf(user.getAddress());
          let tx = roulette.connect(user).newBet([
            {
              amount: 10,
              numbers: [i * 3 + 1, i * 3 + 2, i * 3 + 3],
              betType: BetType.STREET,
            },
          ]);
          await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
          await vrfV2Wrapper.sendRawFulfillRandomWords(
            roulette.getAddress(),
            0,
            [0]
          );
          expect(await roulette.fulfilled(0)).to.be.eq(true);
          const balanceAfter = await token.balanceOf(user.getAddress());
          expect(balanceAfter).to.be.eq(balanceBefore - 10n);
        });
      }

      for (let i = 0; i < 12; i++) {
        it(`street ${i * 3 + 1},${i * 3 + 2},${i * 3 + 3} - won`, async () => {
          const { roulette, user, vrfV2Wrapper, token } =
            await deployRouletteFixture();
          const balanceBefore = await token.balanceOf(user.getAddress());
          let tx = roulette.connect(user).newBet([
            {
              amount: 10,
              numbers: [i * 3 + 1, i * 3 + 2, i * 3 + 3],
              betType: BetType.STREET,
            },
          ]);
          await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
          await vrfV2Wrapper.sendRawFulfillRandomWords(
            roulette.getAddress(),
            0,
            [i * 3 + Math.floor(Math.random() * 3) + 1]
          );
          expect(await roulette.fulfilled(0)).to.be.eq(true);
          const balanceAfter = await token.balanceOf(user.getAddress());
          expect(balanceAfter).to.be.eq(balanceBefore + 10n * 11n);
        });
      }
    });

    describe("split bet", function () {
      it("without nunbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette
            .connect(user)
            .newBet([{ amount: 10, numbers: [], betType: BetType.SPLIT }])
        ).to.be.revertedWith("Invalid numbers length");
      });

      it("with 1 number - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette
            .connect(user)
            .newBet([{ amount: 10, numbers: [1], betType: BetType.SPLIT }])
        ).to.be.revertedWith("Invalid numbers length");
      });

      it("with invalid combination - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette
            .connect(user)
            .newBet([{ amount: 10, numbers: [20, 24], betType: BetType.SPLIT }])
        ).to.be.revertedWith("Invalid combination");
      });

      it("success with won", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette
          .connect(user)
          .newBet([{ amount: 10, numbers: [17, 20], betType: BetType.SPLIT }]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          20,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 17n);
      });
    });

    describe("corner bet", function () {
      it("without nunbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette
            .connect(user)
            .newBet([{ amount: 10, numbers: [], betType: BetType.CORNER }])
        ).to.be.revertedWith("Invalid numbers length");
      });

      it("with 3 numbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette
            .connect(user)
            .newBet([
              { amount: 10, numbers: [1, 2, 3], betType: BetType.CORNER },
            ])
        ).to.be.revertedWith("Invalid numbers length");
      });

      it("with invalid combination - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette
            .connect(user)
            .newBet([
              { amount: 10, numbers: [4, 5, 6, 9], betType: BetType.CORNER },
            ])
        ).to.be.revertedWith("Invalid combination");
      });

      it("success with won", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette
          .connect(user)
          .newBet([
            { amount: 10, numbers: [17, 18, 20, 21], betType: BetType.CORNER },
          ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          20,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 8n);
      });
    });

    describe("double street bet", function () {
      it("without nunbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette
            .connect(user)
            .newBet([
              { amount: 10, numbers: [], betType: BetType.DOUBLE_STREET },
            ])
        ).to.be.revertedWith("Invalid numbers length");
      });

      it("with 5 numbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette.connect(user).newBet([
            {
              amount: 10,
              numbers: [1, 2, 3, 4, 5],
              betType: BetType.DOUBLE_STREET,
            },
          ])
        ).to.be.revertedWith("Invalid numbers length");
      });

      it("with invalid combination - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette.connect(user).newBet([
            {
              amount: 10,
              numbers: [1, 2, 3, 4, 5, 9],
              betType: BetType.DOUBLE_STREET,
            },
          ])
        ).to.be.revertedWith("Invalid combination");
      });

      it("success with won", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette.connect(user).newBet([
          {
            amount: 10,
            numbers: [19, 20, 21, 22, 23, 24],
            betType: BetType.DOUBLE_STREET,
          },
        ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          20,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 5n);
      });

      it("success with won (reverted numbers)", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette.connect(user).newBet([
          {
            amount: 10,
            numbers: [21, 20, 19, 24, 23, 22],
            betType: BetType.DOUBLE_STREET,
          },
        ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          20,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 5n);
      });
    });

    describe("straight up bet", function () {
      it("without nunbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette
            .connect(user)
            .newBet([{ amount: 10, numbers: [], betType: BetType.STRAIGHT_UP }])
        ).to.be.revertedWith("Invalid numbers length");
      });

      it("with 5 numbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette.connect(user).newBet([
            {
              amount: 10,
              numbers: [1, 2, 3, 4, 5],
              betType: BetType.STRAIGHT_UP,
            },
          ])
        ).to.be.revertedWith("Invalid numbers length");
      });

      it("success with won", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette.connect(user).newBet([
          {
            amount: 10,
            numbers: [19],
            betType: BetType.STRAIGHT_UP,
          },
        ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          19,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 35n);
      });

      it("success with won - zero", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette.connect(user).newBet([
          {
            amount: 10,
            numbers: [0],
            betType: BetType.STRAIGHT_UP,
          },
        ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          0,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 35n);
      });

      it("success with won - double zero", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette.connect(user).newBet([
          {
            amount: 10,
            numbers: [37],
            betType: BetType.STRAIGHT_UP,
          },
        ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          37,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 35n);
      });
    });

    describe("column bet", function () {
      it("with 5 numbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette.connect(user).newBet([
            {
              amount: 10,
              numbers: [1, 2, 3, 4, 5],
              betType: BetType.FIRST_COLUMN,
            },
          ])
        ).to.be.revertedWith("Numbers not required for this type");
      });

      it("success with won - first column", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette.connect(user).newBet([
          {
            amount: 10,
            numbers: [],
            betType: BetType.FIRST_COLUMN,
          },
        ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          25,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 2n);
      });

      it("success with won - second column", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette.connect(user).newBet([
          {
            amount: 10,
            numbers: [],
            betType: BetType.SECOND_COLUMN,
          },
        ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          17,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 2n);
      });

      it("success with won - third column", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette.connect(user).newBet([
          {
            amount: 10,
            numbers: [],
            betType: BetType.THIRD_COLUMN,
          },
        ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          36,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 2n);
      });
    });

    describe("dozen bet", function () {
      it("with 5 numbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette.connect(user).newBet([
            {
              amount: 10,
              numbers: [1, 2, 3, 4, 5],
              betType: BetType.FIRST_DOZEN,
            },
          ])
        ).to.be.revertedWith("Numbers not required for this type");
      });

      it("success with won - first dozen", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette.connect(user).newBet([
          {
            amount: 10,
            numbers: [],
            betType: BetType.FIRST_DOZEN,
          },
        ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          8,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 2n);
      });

      it("success with won - second dozen", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette.connect(user).newBet([
          {
            amount: 10,
            numbers: [],
            betType: BetType.SECOND_DOZEN,
          },
        ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          18,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 2n);
      });

      it("success with won - third dozen", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette.connect(user).newBet([
          {
            amount: 10,
            numbers: [],
            betType: BetType.THIRD_DOZEN,
          },
        ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          31,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 2n);
      });
    });

    describe("1 - 18 bet", function () {
      it("with 5 numbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette.connect(user).newBet([
            {
              amount: 10,
              numbers: [1, 2, 3, 4, 5],
              betType: BetType.ONE_TO_EIGHTEEN,
            },
          ])
        ).to.be.revertedWith("Numbers not required for this type");
      });

      it("success with won", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette.connect(user).newBet([
          {
            amount: 10,
            numbers: [],
            betType: BetType.ONE_TO_EIGHTEEN,
          },
        ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          8,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 1n);
      });
    });

    describe("19 - 36 bet", function () {
      it("with 5 numbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette.connect(user).newBet([
            {
              amount: 10,
              numbers: [1, 2, 3, 4, 5],
              betType: BetType.NINETEEN_TO_THIRTY_SIX,
            },
          ])
        ).to.be.revertedWith("Numbers not required for this type");
      });

      it("success with won", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette.connect(user).newBet([
          {
            amount: 10,
            numbers: [],
            betType: BetType.NINETEEN_TO_THIRTY_SIX,
          },
        ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          36,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 1n);
      });
    });

    describe("19 - 36 bet", function () {
      it("with 5 numbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette.connect(user).newBet([
            {
              amount: 10,
              numbers: [1, 2, 3, 4, 5],
              betType: BetType.NINETEEN_TO_THIRTY_SIX,
            },
          ])
        ).to.be.revertedWith("Numbers not required for this type");
      });

      it("success with won", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette.connect(user).newBet([
          {
            amount: 10,
            numbers: [],
            betType: BetType.NINETEEN_TO_THIRTY_SIX,
          },
        ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          36,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 1n);
      });
    });

    describe("even and odd bet", function () {
      it("with 5 numbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette.connect(user).newBet([
            {
              amount: 10,
              numbers: [1, 2, 3, 4, 5],
              betType: BetType.EVEN,
            },
          ])
        ).to.be.revertedWith("Numbers not required for this type");
      });

      it("success with won - even", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette.connect(user).newBet([
          {
            amount: 10,
            numbers: [],
            betType: BetType.EVEN,
          },
        ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          24,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 1n);
      });

      it("success with won - odd", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette.connect(user).newBet([
          {
            amount: 10,
            numbers: [],
            betType: BetType.ODD,
          },
        ]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          23,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 1n);
      });
    });

    describe("red and black bet", function () {
      it("with 5 numbers - revert", async () => {
        const { roulette, user } = await deployRouletteFixture();
        await expect(
          roulette
            .connect(user)
            .newBet([
              { amount: 10, numbers: [1, 2, 3, 4, 5], betType: BetType.RED },
            ])
        ).to.be.revertedWith("Numbers not required for this type");
      });

      it("success with won - red", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette
          .connect(user)
          .newBet([{ amount: 10, numbers: [], betType: BetType.RED }]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          18,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 1n);
      });

      it("success with won - black", async () => {
        const { roulette, user, vrfV2Wrapper, token } =
          await deployRouletteFixture();
        const balanceBefore = await token.balanceOf(user.getAddress());
        let tx = roulette
          .connect(user)
          .newBet([{ amount: 10, numbers: [], betType: BetType.BLACK }]);
        await expect(tx).to.emit(roulette, "BetsCreated").withArgs(0, 100);
        await vrfV2Wrapper.sendRawFulfillRandomWords(roulette.getAddress(), 0, [
          20,
        ]);
        expect(await roulette.fulfilled(0)).to.be.eq(true);
        const balanceAfter = await token.balanceOf(user.getAddress());
        expect(balanceAfter).to.be.eq(balanceBefore + 10n * 1n);
      });
    });
  });
});
