// https://github.com/PatrickAlphaC/hardhat-smartcontract-lottery-fcc/blob/main/test/staging/lottery.staging.test.js
const {assert, expect} = require('chai');
const {getNamedAccounts, ethers, network} = require('hardhat');
const {developmentChains} = require('../../helper-hardhat-config');

developmentChains.includes(network.name)
  ? describe.skip
  : describe('Lottery Staging Tests', () => {
      let lottery, lotteryEntranceFee, deployer;

      beforeEach(async () => {
        deployer = (await getNamedAccounts()).deployer;
        lottery = await ethers.getContract('Lottery', deployer);
        lotteryEntranceFee = await lottery.getEntranceFee();
      });

      describe('fulfillRandomWords', () => {
        it('works with live Chainlink Keepers and Chainlink VRF, we get a random winner', async () => {
          // enter the lottery
          console.log('Setting up test...');
          const startingTimeStamp = await lottery.getLatestTimestamp();
          const accounts = await ethers.getSigners();

          console.log('Setting up Listener...');
          await new Promise(async (resolve, reject) => {
            // setup listener before we enter the lottery
            // Just in case the blockchain moves REALLY fast
            lottery.once('WinnerPicked', async () => {
              console.log('WinnerPicked event fired!');
              try {
                // add our asserts here
                const recentWinner = await lottery.getRecentWinner();
                const lotteryState = await lottery.getlotteryState();
                const winnerEndingBalance = await accounts[0].getBalance();
                const endingTimeStamp = await lottery.getLatestTimestamp();

                await expect(lottery.getPlayer(0)).to.be.reverted;
                assert.equal(recentWinner.toString(), accounts[0].address);
                assert.equal(lotteryState, 0);
                assert.equal(
                  winnerEndingBalance.toString(),
                  winnerStartingBalance.add(lotteryEntranceFee).toString()
                );
                assert(endingTimeStamp > startingTimeStamp);
                resolve();
              } catch (error) {
                console.log(error);
                reject(error);
              }
            });
            // Then entering the lottery
            console.log('Entering lottery...');
            const tx = await lottery.enterLottery({value: lotteryEntranceFee});
            await tx.wait(1);
            console.log('Ok, time to wait...');
            const winnerStartingBalance = await accounts[0].getBalance();
            console.log('winnerStartingBalance', winnerStartingBalance);
            // and this code WONT complete until our listener has finished listening!
          });
        });
      });
    });
