import "./styles.css";
import { ElderSoulsGame } from "./game.js";

const root = document.querySelector("#app");
const game = new ElderSoulsGame(root);
game.start();

window.elderSouls = game;
