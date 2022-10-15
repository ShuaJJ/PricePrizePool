import { UserOutlined } from "@ant-design/icons";
import { Button, Popover } from "antd";
import React from "react";
import { useThemeSwitcher } from "react-css-theme-switcher";

import Address from "./Address";
import Balance from "./Balance";
import Wallet from "./Wallet";

/** 
  ~ What it does? ~

  Displays an Address, Balance, and Wallet as one Account component,
  also allows users to log in to existing accounts and log out

  ~ How can I use? ~

  <Account
    address={address}
    localProvider={localProvider}
    userProvider={userProvider}
    mainnetProvider={mainnetProvider}
    price={price}
    web3Modal={web3Modal}
    loadWeb3Modal={loadWeb3Modal}
    logoutOfWeb3Modal={logoutOfWeb3Modal}
    blockExplorer={blockExplorer}
    isContract={boolean}
  />

  ~ Features ~

  - Provide address={address} and get balance corresponding to the given address
  - Provide localProvider={localProvider} to access balance on local network
  - Provide userProvider={userProvider} to display a wallet
  - Provide mainnetProvider={mainnetProvider} and your address will be replaced by ENS name
              (ex. "0xa870" => "user.eth")
  - Provide price={price} of ether and get your balance converted to dollars
  - Provide web3Modal={web3Modal}, loadWeb3Modal={loadWeb3Modal}, logoutOfWeb3Modal={logoutOfWeb3Modal}
              to be able to log in/log out to/from existing accounts
  - Provide blockExplorer={blockExplorer}, click on address and get the link
              (ex. by default "https://etherscan.io/" or for xdai "https://blockscout.com/poa/xdai/")
**/

export default function Account({
  address,
  userSigner,
  localProvider,
  mainnetProvider,
  price,
  minimized,
  web3Modal,
  loadWeb3Modal,
  logoutOfWeb3Modal,
  blockExplorer,
  isContract,
}) {
  const info = userSigner && (
    <div>
      <Balance address={address} provider={localProvider} price={price} size={20} dollar={false} />
      <Button type="secondary" onClick={logoutOfWeb3Modal}>
        Logout
      </Button>
    </div>
  );

  let accountButtonInfo;
  if (web3Modal?.cachedProvider) {
    accountButtonInfo = { name: "Logout", action: logoutOfWeb3Modal };
    return (
      <Popover content={info} trigger="click">
        <Button
          type="primary"
          style={{
            marginLeft: 8,
            padding: "0px 15px",
            fontSize: "17px",
            color: "#111",
            height: "42px",
            fontWeight: "600",
          }}
          shape="round"
        >
          {address?.substr(0, 5) + "..." + address?.substr(-4)}
        </Button>
      </Popover>
    );
  } else {
    accountButtonInfo = { name: "Connect", action: loadWeb3Modal };
  }

  const display = !minimized && (
    <span>
      {address && (
        <>
          <Address address={address} ensProvider={mainnetProvider} blockExplorer={blockExplorer} fontSize={20} />
          <Balance address={address} provider={localProvider} price={price} size={20} />
        </>
      )}
    </span>
  );

  return (
    <div style={{ display: "flex" }}>
      {display}
      {web3Modal && (
        <Button
          type="primary"
          style={{
            marginLeft: 8,
            padding: "0px 36px",
            fontSize: "17px",
            color: "#111",
            height: "42px",
            fontWeight: "600",
          }}
          shape="round"
          onClick={accountButtonInfo.action}
        >
          {accountButtonInfo.name}
        </Button>
      )}
    </div>
  );
}
