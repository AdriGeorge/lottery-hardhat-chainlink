const {assert, expect} = require('chai');
const {getNamedAccounts, deployments, ethers} = require('hardhat');
const {
  developmentChains,
  networkConfig,
} = require('../../helper-hardhat-config');

!developmentChains.includes(network.name)
  ? describe.skip
  : describe('Lottery', async () => {
      let lottery, vrfCoordinatorV2Mock, lotteryEntranceFee, interval, player;

      beforeEach(async () => {
        const {deployer} = await getNamedAccounts;
        await deployments.fixture(['all']);
        lottery = await ethers.getContract('Lottery', deployer);
        vrfCoordinatorV2Mock = await ethers.getContract(
          'VRFCoordinatorV2Mock',
          deployer
        );
        lotteryEntranceFee = await lottery.getEntranceFee();
        interval = await lottery.getInterval();
      });

      describe('Constructor', async () => {
        it('Inizializes the lottery correctly', async () => {
          const lotteryState = await lottery.getLotteryState();
          assert.equal(lotteryState.toString(), 0);
          assert.equal(
            interval.toString(),
            networkConfig[network.config.chainId]['keepersUpdateInterval']
          );
        });
      });

      describe('Enter lottery', async () => {
        it("revert when you don't pay enough", async () => {
          await expect(lottery.enterLottery()).to.be.revertedWith(
            'Lottery__NotEnougETHEntered'
          );
        });
        it('record player when they enter', async () => {
          let numPlayers = await lottery.getNumPlayers();
          assert(numPlayers.toString(), 0);
          await lottery.enterLottery({value: lotteryEntranceFee});
          numPlayers = await lottery.getNumPlayers();
          assert(numPlayers.toString(), 1);
        });
        it('emits event on enter', async () => {
          // let tx = await lottery.enterLottery({value: lotteryEntranceFee});
          // let txResolved = await tx.wait();
          // console.log('event:', txResolved.events[0].event);
          await expect(
            lottery.enterLottery({value: lotteryEntranceFee})
          ).to.emit(lottery, 'LotteryEnter');
        });
        it("doesn't allow entrance when lottery is calculating", async () => {
          await lottery.enterLottery({value: lotteryEntranceFee});

          await network.provider.send('evm_increaseTime', [
            interval.toNumber() + 1,
          ]);
          await network.provider.request({method: 'evm_mine', params: []});

          await lottery.performUpkeep([]);
          await expect(
            lottery.enterLottery({value: lotteryEntranceFee})
          ).to.be.revertedWith('Lottery__NotOpen');
        });
      });
    });
