import React from "react";
import { Typography } from "antd";

const { Title } = Typography;

// displays a page header

export default function Header({ link, title, subTitle, ...props }) {
  return (
    <div style={{ display: "flex", justifyContent: "space-between", padding: "1.2rem" }}>
      <div style={{ display: "flex", flexDirection: "column", flex: 1, alignItems: "start" }}>
        <a href={link} target="_blank" rel="noopener noreferrer">
          <Title level={6} style={{ margin: "0 0.5rem 0 0" }}>
            <img alt="logo" style={{ width: "60px", marginRight: "8px" }} src="/logo.png" /> Price Prize Pool
          </Title>
        </a>
      </div>
      {props.children}
    </div>
  );
}
