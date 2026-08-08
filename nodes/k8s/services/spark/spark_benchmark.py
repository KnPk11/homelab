import sys
import time
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sha2, concat, sin, cos, tan

def main():
    num_records = int(sys.argv[1]) if len(sys.argv) > 1 else 6000000
    partitions = int(sys.argv[2]) if len(sys.argv) > 2 else 6
    
    start_time = time.time()
    spark = SparkSession.builder.appName("Spark-Speedup-Benchmark").getOrCreate()

    df = spark.range(0, num_records, 1, numPartitions=partitions)
    expr_df = df
    for i in range(10):
        expr_df = expr_df.withColumn(
            f"calc_{i}", 
            sha2(concat(col("id"), sin(col("id") + i), cos(col("id") + i), tan(col("id") + i + 1)), 512)
        )

    # Force execution of every partition using noop sink (prevents Spark SQL column pruning)
    expr_df.write.format("noop").mode("overwrite").save()

    duration = time.time() - start_time
    print(f"COMPLETED {num_records:,} RECORDS IN {duration:.2f} SECONDS ({duration/60:.2f} MINUTES)")
    spark.stop()

if __name__ == "__main__":
    main()
