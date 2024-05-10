const { ethers } = require("ethers");

exports.fromEther = (value) => {
    return Number(ethers.formatEther(value));
};

exports.toEther = (value) => {
    return ethers.parseEther(`${value}`);
};

exports.fromStable = (value) => {
    return Number(ethers.formatUnits(value, 6));
};

exports.toStable = (value) => {
    return ethers.parseUnits(`${value}`, 6);
};