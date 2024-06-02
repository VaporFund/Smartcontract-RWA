const { ethers } = require("hardhat")
const { expect } = require("chai")

describe("#multiSignController", () => {

    let controller
    let callme

    let alice
    let bob
    let charlie
    let dave
    let vincent

    const Role = {
        SET_ADMIN: 0,
        ADD_OPERATOR: 1,
        REMOVE_OPERATOR: 2
    };

    before(async() => {

        [alice, bob, charlie, dave, vincent] = await ethers.getSigners()

        const MultiSigController = await ethers.getContractFactory("MultiSigController")
        const CallMe = await ethers.getContractFactory("CallMe")

        // controller = await MultiSigController.deploy([alice.address, bob.address], 2)
        controller = await upgrades.deployProxy(MultiSigController, [
            alice.address, [alice.address, bob.address], 2
        ]);
        callme = await CallMe.deploy(controller.target)
    })


    it("should submit a request to set role", async() => {
        const initialRoleRequestsCount = await controller.getRoleRequestCount()

        const role = Role.ADD_OPERATOR;
        const account = vincent.address;
        await controller.connect(alice).submitRoleRequest(role, account);

        const newRequest = await controller.getRoleRequest(initialRoleRequestsCount);

        expect(newRequest.account).to.equal(account);
        expect(newRequest.executed).to.be.false;
        expect(newRequest.numConfirmations).to.equal(0);
    });

    it("should add and remove new operators success", async function() {

        let operators = await controller.getOperators()
        expect(operators.length).to.equal(2)

        // add charlie and dave
        const requestAddCharlie = await controller.getRoleRequestCount()
        await controller.connect(alice).submitRoleRequest(Role.ADD_OPERATOR, charlie.address)

        const requestAddDave = await controller.getRoleRequestCount()
        await controller.connect(alice).submitRoleRequest(Role.ADD_OPERATOR, dave.address)

        const requestAddVincent = await controller.getRoleRequestCount()
        await controller.connect(alice).submitRoleRequest(Role.ADD_OPERATOR, vincent.address)

        await controller.connect(alice).confirmRoleRequest(requestAddCharlie)
        await controller.connect(bob).confirmRoleRequest(requestAddCharlie)
        await controller.connect(alice).executeRoleRequest(requestAddCharlie)


        await controller.connect(alice).confirmRoleRequest(requestAddDave)
        await controller.connect(bob).confirmRoleRequest(requestAddDave)
        await controller.connect(charlie).confirmRoleRequest(requestAddDave)
        await controller.connect(alice).executeRoleRequest(requestAddDave)


        await controller.connect(alice).confirmRoleRequest(requestAddVincent)
        await controller.connect(bob).confirmRoleRequest(requestAddVincent)
        await controller.connect(charlie).confirmRoleRequest(requestAddVincent)
        await controller.connect(dave).confirmRoleRequest(requestAddVincent)
        await controller.connect(alice).executeRoleRequest(requestAddVincent)



        operators = await controller.getOperators()
        expect(operators.length).to.equal(5)

        operators = await controller.getOperators()
        expect(operators.filter(item => item !== ethers.ZeroAddress).length).to.equal(5)

        const requestRemoveVincent = await controller.getRoleRequestCount()
        await controller.connect(alice).submitRoleRequest(Role.REMOVE_OPERATOR, vincent.address)

        await controller.connect(alice).confirmRoleRequest(requestRemoveVincent)
        await controller.connect(bob).confirmRoleRequest(requestRemoveVincent)
        await controller.connect(charlie).confirmRoleRequest(requestRemoveVincent)

        await controller.connect(alice).executeRoleRequest(requestRemoveVincent) // 3/4 sign

        operators = await controller.getOperators()
        expect(operators.length).to.equal(4)

        // transfer admin permission
        await controller.connect(alice).transferAdmin(vincent.address)
    })

    it("should add new admin success", async function() {

        const requestSetAdminId = await controller.getRoleRequestCount()
        await controller.connect(alice).submitRoleRequest(Role.SET_ADMIN, bob.address)

        await controller.connect(alice).confirmRoleRequest(requestSetAdminId)
        await controller.connect(bob).confirmRoleRequest(requestSetAdminId)
        await controller.connect(charlie).confirmRoleRequest(requestSetAdminId)

        await controller.connect(alice).executeRoleRequest(requestSetAdminId)

        const isAdmin = await controller.isAdmin(bob.address)
        expect(isAdmin).to.equal(true)
    })

    it("should received request submission from another contract success", async function() {

        // add supported contract
        await controller.connect(bob).addContract(callme.target)

        // submit 3 requests
        await callme.submit()
        await callme.submit()
        await callme.submit()

        // now approve and execute all of them
        for (let i = 0; i < 3; i++) {
            await controller.connect(charlie).confirmRequest(i)
            await controller.connect(dave).confirmRequest(i)
            await controller.connect(dave).executeRequest(i)
        }

        // result should equal 123+123+123
        expect(await callme.i()).to.equal(BigInt(369))

    })


    it("should set number of confirmations required", async() => {
        const newNumConfirmationsRequired = 3; // Change it according to your test case

        // Call the setNumConfirmationsRequired function
        await controller.connect(bob).setNumConfirmationsRequired(newNumConfirmationsRequired);

        // Get the updated value of numConfirmationsRequired
        const numConfirmationsRequired = await controller.numConfirmationsRequired();

        // Assert that the value has been set correctly
        expect(numConfirmationsRequired).to.equal(newNumConfirmationsRequired);
    });
})