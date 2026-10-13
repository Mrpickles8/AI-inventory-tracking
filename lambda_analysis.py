import boto3
import json
import os
import pymysql


def lambda_handler(event, context):
    db = None

    try:
        # Connexion à RDS
        db = pymysql.connect(
            host=os.environ["DB_HOST"],
            user="admin",
            password=os.environ["DB_PASSWORD"],
            database="inventory",
            cursorclass=pymysql.cursors.DictCursor,
            connect_timeout=5,
        )

        # Récupération des produits avec un stock faible
        with db.cursor() as cursor:
            cursor.execute(
                """
                SELECT *
                FROM products
                WHERE quantity < 10
                ORDER BY quantity ASC
                """
            )
            low_stock = cursor.fetchall()

            # Récupération des 20 produits à analyser
            cursor.execute(
                """
                SELECT name, quantity, price
                FROM products
                ORDER BY quantity ASC
                LIMIT 20
                """
            )
            all_products = cursor.fetchall()

        # Analyse IA avec Amazon Bedrock
        bedrock = boto3.client(
            "bedrock-runtime",
            region_name="eu-west-1",
        )

        prompt = (
            "Analyze this inventory and give 3 specific recommendations "
            "to optimize stock. Consider low quantities and product prices.\n\n"
            f"Inventory data:\n{json.dumps(all_products, default=str)}"
        )

        response = bedrock.invoke_model(
            modelId="anthropic.claude-3-haiku-20240307-v1:0",
            contentType="application/json",
            accept="application/json",
            body=json.dumps(
                {
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": 500,
                    "messages": [
                        {
                            "role": "user",
                            "content": prompt,
                        }
                    ],
                }
            ),
        )

        response_body = json.loads(response["body"].read())
        ai_analysis = response_body["content"][0]["text"]

        # Envoi du rapport par email avec Amazon SES
        ses = boto3.client(
            "ses",
            region_name="eu-west-1",
        )

        email_body = f"""
Daily Inventory AI Report

Low Stock Items ({len(low_stock)} products):
{json.dumps(low_stock, indent=2, ensure_ascii=False, default=str)}

AI Recommendations:
{ai_analysis}
"""

        ses.send_email(
            Source=os.environ["SENDER_EMAIL"],
            Destination={
                "ToAddresses": [os.environ["ADMIN_EMAIL"]],
            },
            Message={
                "Subject": {
                    "Data": "Daily AI Inventory Report",
                    "Charset": "UTF-8",
                },
                "Body": {
                    "Text": {
                        "Data": email_body,
                        "Charset": "UTF-8",
                    }
                },
            },
        )

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": "Inventory report sent successfully",
                    "low_stock_count": len(low_stock),
                }
            ),
        }

    except Exception:
        # Enregistre l'erreur dans Amazon CloudWatch Logs
        import logging

        logging.exception("Failed to generate inventory report")

        return {
            "statusCode": 500,
            "body": json.dumps(
                {
                    "message": "Failed to generate inventory report",
                }
            ),
        }

    finally:
        # Fermeture de la connexion à la base de données
        if db is not None:
            db.close()