import React, { useState } from "react";
import { useContractLoader } from "eth-hooks";
import Balance from "../Balance";
import "./index.css";
import { Button, Input } from "antd";

export default function Deposit({ customContract, provider, name, price, chainId, address, contractConfig }) {
  const contracts = useContractLoader(provider, contractConfig, chainId);
  let contract;
  if (!customContract) {
    contract = contracts ? contracts[name] : "";
  } else {
    contract = customContract;
  }

  return (
    <div className="deposit-wrapper">
      <div className="pool-balance">
        <Balance address={address} provider={provider} price={price} size={88} />
      </div>
      <div className="balance-info">IN PRIZE POOL</div>
      <div className="deposit-form">
        <Input addonBefore="$" type="number" placeholder={"My Guess: " + price} />
        <Input addonAfter="ETH" type="number" placeholder="My Bet: Minimum 0.01" />
        <Button className="deposit-btn" type="primary">
          Deposit
        </Button>
        <a
          href="https://jojos-metaverse.gitbook.io/priceprizepool/"
          target="_blank"
          className="instructions"
          rel="noreferrer"
        >
          HOW TO PLAY?
        </a>
      </div>
    </div>
  );
}
