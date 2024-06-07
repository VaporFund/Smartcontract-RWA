const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("#role-manage", function() {
    let RoleManage;
    let roleManage;
    let owner;
    let addr1;
    let addr2;

    beforeEach(async function() {
        RoleManage = await ethers.getContractFactory("RoleManage");
        [owner, addr1, addr2] = await ethers.getSigners();
        roleManage = await RoleManage.deploy(owner.address);
    });

    it("should set the correct role super admin", async function() {
        expect(await roleManage.roleSuperAdmin()).to.equal(owner.address);
    });

    it("should set a role", async function() {
        const role = ethers.keccak256(ethers.toUtf8Bytes("ROLE"));
        await roleManage.setRole(role);
        expect(await roleManage.rolePermissions(role)).to.equal(true);
        expect(await roleManage.roles(0)).to.equal(role);
    });

    it("should revoke a role", async function() {
        const role = ethers.keccak256(ethers.toUtf8Bytes("ROLE"));
        await roleManage.setRole(role);
        await roleManage.revokeRole(role);
        expect(await roleManage.rolePermissions(role)).to.equal(false);
        expect(Array.from(await roleManage.getAllRoles()).length).to.equal(0);
    });

    it("should set a role address", async function() {
        const role = ethers.keccak256(ethers.toUtf8Bytes("ROLE"));
        await roleManage.setRole(role);
        await roleManage.setRoleAddress(role, addr1.address);
        expect(await roleManage.isValidate(role, addr1.address)).to.equal(true);
    });

    it("should revoke a role address", async function() {
        const role = ethers.keccak256(ethers.toUtf8Bytes("ROLE"));
        await roleManage.setRole(role);
        await roleManage.setRoleAddress(role, addr1.address);
        await roleManage.revokeRoleAddress(role, addr1.address);
        expect(await roleManage.isValidate(role, addr1.address)).to.equal(false);
    });

    it("should validate a role address", async function() {
        const role = ethers.keccak256(ethers.toUtf8Bytes("ROLE"));
        await roleManage.setRole(role);
        await roleManage.setRoleAddress(role, addr1.address);
        expect(await roleManage.isValidate(role, addr1.address)).to.equal(true);
        expect(await roleManage.isValidate(role, addr2.address)).to.equal(false);
    });

    it("should return true if an address is the super admin", async function() {
        expect(await roleManage.isSupperAdmin(owner.address)).to.equal(true);
        expect(await roleManage.isSupperAdmin(addr1.address)).to.equal(false);
    });

    it("should return true if an address is the contract owner", async function() {
        expect(await roleManage.isOwner(owner.address)).to.equal(true);
        expect(await roleManage.isOwner(addr1.address)).to.equal(false);
    });
});