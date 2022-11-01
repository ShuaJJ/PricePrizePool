import "./index.css";
import { Button, Input, notification } from "antd";
import { useState } from "react";
import PPCountDown from "../CountDown";
const { ethers } = require("ethers");

export default function Deposit({
  provider,
  price,
  generalInfo,
  writeContracts,
  guessingEndTime,
  isCorrectNetwork,
  userSigner,
  tx,
}) {
  const [guess, setGuess] = useState();
  const [bet, setBet] = useState();
  const [loading, setLoading] = useState(false);
  const [depositHash, setDepositHash] = useState();

  var roundTotal,
    guessingEndTime = 0;
  if (generalInfo) {
    roundTotal = generalInfo[3];
    guessingEndTime = generalInfo[1].toNumber() * 1000;
  }

  const onGuessChange = e => {
    setGuess(e.target.value);
  };

  const onBetChange = e => {
    setBet(e.target.value);
  };

  const deposit = async () => {
    if (!(provider && userSigner)) {
      notification["error"]({
        message: "Please connect your wallet first!",
      });
      return;
    }

    if (!isCorrectNetwork) {
      notification["error"]({
        message: "Please switch to Goerli first!",
      });
      return;
    }

    if (!guess) {
      notification["error"]({
        message: "Please make your guess!",
      });
      return;
    }

    if (!bet || bet < 0.01) {
      notification["error"]({
        message: "Please deposit at minimum 0.01 ETH to make a guess!",
      });
      return;
    }

    setLoading(true);

    const value = ethers.utils.parseEther(bet.toString());
    const finalGuess = parseInt(guess);

    const result = tx(writeContracts.PricePrizePool.deposit(finalGuess, { value: value }), update => {
      if (update) {
        setDepositHash(update.hash);
      }
      setLoading(false);
    });
  };

  const now = new Date();
  const guessingTimeIsOver = now.getTime() > guessingEndTime;

  return (
    <div className="deposit-wrapper">
      <PPCountDown isPrize={false} generalInfo={generalInfo} />
      <div className="pool-balance">{roundTotal && ethers.utils.formatEther(roundTotal)}</div>
      <div className="balance-info">IN PRIZE POOL</div>
      <div className="deposit-form">
        <Input
          addonBefore="USD"
          type="number"
          placeholder={"My Guess: " + price.toFixed(0)}
          onChange={onGuessChange}
          value={guess}
        />
        <Input addonAfter="ETH" type="number" placeholder="My Bet: Minimum 0.01" onChange={onBetChange} value={bet} />
        <Button
          className="deposit-btn"
          type="primary"
          onClick={deposit}
          loading={loading}
          disabled={guessingTimeIsOver}
        >
          Deposit
        </Button>
        {depositHash && (
          <a
            target="_blank"
            style={{ marginTop: "4px", textDecoration: "underline", display: "block" }}
            href={"https://goerli.etherscan.io/tx/" + depositHash}
            rel="noreferrer"
          >
            {depositHash}
          </a>
        )}
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
