import "puppeteer-core";
import chromium from "chrome-aws-lambda";
import fetch from "node-fetch";
import { SQSHandler } from "aws-lambda";

interface PdfRequest {
    destination: string;
}

export const render: SQSHandler = async (event, _context) => {
    try {
        for (const message of event.Records) {
            const job: PdfRequest = JSON.parse(message.body);

            const browser = await chromium.puppeteer.launch({
                args: chromium.args,
                defaultViewport: chromium.defaultViewport,
                executablePath: await chromium.executablePath,
                headless: chromium.headless,
                ignoreHTTPSErrors: true
            });

            const page = await browser.newPage();

            await page.goto("https://localstack.cloud/", {
                waitUntil: ["networkidle0", "load", "domcontentloaded"]
            });

            const stream = await page.pdf({ printBackground: true });

            job.destination = job.destination.replace('localhost', process.env.LOCALSTACK_HOSTNAME);

            await fetch(job.destination, {
                method: "PUT",
                body: stream.toString("binary"),
                headers: { "Content-Type": "application/pdf" }
            });
        }
    } catch (e) {
        console.error(e);
    }
};
