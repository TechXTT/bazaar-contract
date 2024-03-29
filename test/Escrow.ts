import {
    time,
    loadFixture,
  } from "@nomicfoundation/hardhat-toolbox/network-helpers";
  import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
  import { expect } from "chai";
  import { ethers } from "hardhat";
  
  describe("Escrow", () => {
    let Escrow;
    let escrow: any;
    let buyerAddress: any;
    let sellerAddress: any;

    const orderId1 = '0x3165636239313538326132363433353762656666376536303639313464386638';
    const orderId2 = '0x3739383233303838353162623431303862336263663130663362303537373039';
    const orderId3 = '0x3131366166613135613931383438356538353836636638643632303034396430';
    const orderId4 = '0x3936633137313765613530623436326139333961666339313535343764303762';

    before(async () => {
        Escrow = await ethers.getContractFactory("Escrow");

        [buyerAddress, sellerAddress] = await ethers.getSigners();

        // Deploy the contract
        escrow = await Escrow.deploy();
        
        // Wait for the contract to be mined
        await escrow.deployed();

        // create an order
        await escrow.connect(buyerAddress).createOrder(orderId2, sellerAddress, 10000, { value: ethers.parseUnits('50', 'wei')})
    })

    it('------------------------Creating------------------------', async () => {})
    it('- Should revert if the unlockTime is not in the future', async () => {
        await expect(escrow.connect(buyerAddress).createOrder(orderId1, sellerAddress, 0, { value: ethers.parseUnits('50', 'wei')})).to.be.revertedWith('Release time must be greater than 0')
    })
    it('- Should revert if the recieverAddress is the zero address', async () => {
        await expect(escrow.connect(buyerAddress).createOrder(orderId1, '0x0', 1, { value: ethers.parseUnits('50', 'wei')})).to.be.revertedWith('Invalid receiver address')
    })
    it('- Should revert if the Buyer and the receiver are the same', async () => {
        await expect(escrow.connect(buyerAddress).createOrder(orderId1, buyerAddress, 1, { value: ethers.parseUnits('50', 'wei')})).to.be.revertedWith('Buyer and receiver cannot be the same')
    })
    it('- Should revert if the amount is 0', async () => {
        await expect(escrow.connect(buyerAddress).createOrder(orderId1, sellerAddress, 1, { value: ethers.parseUnits('0', 'wei')})).to.be.revertedWith('Amount must be greater than 0')
    })
    it('- Should revert if the order already exists', async () => {
        await expect(escrow.connect(buyerAddress).createOrder(orderId2, sellerAddress, 1, { value: ethers.parseUnits('50', 'wei')})).to.be.revertedWith('Order ID already exists')
    })
    it('+ Should create an order', async () => {
        await escrow.connect(buyerAddress).createOrder(orderId1, sellerAddress, 1, { value: ethers.parseUnits('50', 'wei')})
        const order = await escrow.orders(orderId1)
        expect(order.buyer).to.equal(buyerAddress.address)
        expect(order.receiver).to.equal(sellerAddress.address)
        expect(order.amount).to.equal(ethers.parseUnits('50', 'wei'))
        expect(order.completed).to.equal(false)
    })

    it('------------------------Claiming------------------------', async () => {})
    it('- Should revert if the order does not exist', async () => {
        await expect(escrow.connect(sellerAddress).claimOrder('0x0')).to.be.revertedWith('Order ID does not exist')
    })
    it('- Should revert if the caller is not the receiver', async () => {
        await expect(escrow.connect(buyerAddress).claimOrder(orderId1)).to.be.revertedWith('Only reciever can claim')
    })
    it('- Should revert if the unlockTime has not passed', async () => {
        await expect(escrow.connect(sellerAddress).claimOrder(orderId2)).to.be.revertedWith('Release time not reached')
    })
    it('+ Should complete the order', async () => {
        const recieverBalance = await ethers.provider.getBalance(sellerAddress.address)
        await escrow.connect(sellerAddress).claimOrder(orderId1)
        const order = await escrow.orders(orderId1)
        expect(order.completed).to.equal(true)
        const newRecieverBalance = await ethers.provider.getBalance(sellerAddress.address)
        expect(newRecieverBalance).to.gt(recieverBalance)
    })
    it('- Should revert if the order is already completed', async () => {
        await expect(escrow.connect(sellerAddress).claimOrder(orderId1)).to.be.revertedWith('Order already completed')
    })

    it('------------------------Data Fetching------------------------', async () => {})
    it('+ Should get the order', async () => {
        const orderIds = await escrow.getUserIncompleteOrders(buyerAddress)
        expect(orderIds.length).to.equal(1)
        expect(orderIds[0]).to.equal(orderId2)
    })
    it('+ Should get the order', async () => {
        const orderIds = await escrow.getUserCompleteOrders(sellerAddress)
        expect(orderIds.length).to.equal(1)
        expect(orderIds[0]).to.equal(orderId1)
    })

    it('------------------------Refunded------------------------', async () => {})
    it('- Should revert if the order does not exist', async () => {
        await expect(escrow.connect(buyerAddress).refundOrder('0x0')).to.be.revertedWith('Order ID does not exist')
    })
    it('- Should revert if the caller is not the receiver', async () => {
        await expect(escrow.connect(sellerAddress).refundOrder(orderId2)).to.be.revertedWith('Only receiver can refund')
    })
    it('- Should revert if the order is already completed', async () => {
        await expect(escrow.connect(sellerAddress).refundOrder(orderId1)).to.be.revertedWith('Order already completed')
    })
    it('+ Should refund the order', async () => {
        await escrow.connect(buyerAddress).createOrder(orderId3, sellerAddress, 1, { value: ethers.parseUnits('50', 'wei')})

        const buyerBalance = await ethers.provider.getBalance(buyerAddress.address)
        await escrow.connect(buyerAddress).refundOrder(orderId2)
        const order = await escrow.orders(orderId2)
        expect(order.completed).to.equal(true)
        const newBuyerBalance = await ethers.provider.getBalance(buyerAddress.address)
        expect(newBuyerBalance).to.gt(buyerBalance)
    })
    
  });
  