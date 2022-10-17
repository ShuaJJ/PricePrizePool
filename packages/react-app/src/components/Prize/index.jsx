import { useContractReader } from "eth-hooks";
import BigNumber from "ethers";
import Balance from "../Balance";
import "./index.css";
import { Button, Input, notification } from "antd";
import { APP_NAME, RPC_POLL_TIME } from "../../constants";
import { useState } from "react";
const { ethers } = require("ethers");

export default function Prize({ provider, price, readContracts, writeContracts, isCorrectNetwork, userSigner, tx }) {
  const ethPrice = useContractReader(readContracts, APP_NAME, "ethPrice", [], RPC_POLL_TIME);
  const winningGuess = useContractReader(readContracts, APP_NAME, "winningGuess", [], RPC_POLL_TIME);
  const priceSetAt = useContractReader(readContracts, APP_NAME, "priceSetAt", [], RPC_POLL_TIME);
  const timestamp = priceSetAt?.toString();
  var date;
  if (timestamp) {
    date = new Date(parseInt(priceSetAt?.toString()) * 1000);
  }

  return (
    <div className="prize-wrapper">
      EthPrice: {ethPrice}
      Winning Guess: {winningGuess}
      priceSetAt: {date?.toLocaleString()}
    </div>
  );
}
