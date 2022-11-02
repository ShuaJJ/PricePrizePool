import React from "react";

export default function TxHashLink({ hash }) {
  if (!hash) {
    return <></>;
  }
  return (
    <a
      target="_blank"
      style={{ marginTop: "4px", textDecoration: "underline", display: "block" }}
      href={"https://goerli.etherscan.io/tx/" + hash}
      rel="noreferrer"
    >
      {hash}
    </a>
  );
}
