import plotly.express as px
import pandas as pd


class LogFileStat:

    @staticmethod
    def log_file_size_distribution(file):
        """
        Visualize how file sizes are distributed, identify outliers, and determine the average or median file size.
        """
        # Load data into a DataFrame
        data = pd.read_csv(file, sep="\t", header=None, names=["file_path", "filename", "size", "lines"])

        # Create histogram of file sizes
        fig = px.histogram(data, x="size", title="File Size Distribution", labels={"size": "File Size"})
        fig.write_html("file_size_distribution.html")

    @staticmethod
    def plot_violin_for_protocols(file_list: str):
        """
        Create violin plots of file size distributions for each protocol without relying on column headers.
        """
        # Load data without headers
        data = pd.read_csv(file_list, sep="\t", header=None)

        # Assign meaningful column names
        data.columns = ["path", "filename", "size", "protocol"]

        # Create violin plot grouped by protocol
        fig = px.violin(
            data,
            y="size",
            x="protocol",
            color="protocol",
            box=True,  # Add a box plot inside the violin
            points="outliers",  # Show all data points
            title="File Size Distribution by Protocol",
            labels={"size": "File Size (Bytes)", "protocol": "Protocol Type"},
        )
        fig.write_html("file_size_violin_by_protocol.html")
        print("Violin plot written to file_size_violin_by_protocol.html")

    # @staticmethod
    # def number_of_lines_vs_file_size(file):
    #     """
    #     Analyze the relationship between file size and number of lines.
    #     For example, determine if larger files generally have more lines.
    #     """
    #     # Load data into a DataFrame
    #     data = pd.read_csv(file, sep="\t", header=None, names=["file_path", "filename", "size", "lines"])
    #
    #     # Create scatter plot for number of lines vs file size
    #     fig = px.scatter(data, x="size", y="lines", hover_name="filename",
    #                      title="Number of Lines vs File Size",
    #                      labels={"size": "File Size (Bytes)", "lines": "Number of Lines"})
    #     fig.write_html("number_of_lines_vs_file_size.html")

    @staticmethod
    def run_log_file_stat(file, output):
        """
        Run the log file statistics generation and save the visualizations in an HTML output file.
        """
        # Generate the visualizations
        LogFileStat.log_file_size_distribution(file)
        LogFileStat.plot_violin_for_protocols(file)

        # Combine the HTML files
        with open(output, "w") as f:
            f.write("<h1>Log File Statistics</h1>")

            # Embed the content of the generated HTML plots
            with open("file_size_distribution.html", "r") as dist_file:
                f.write(dist_file.read())
            with open("file_size_violin_by_protocol.html", "r") as lines_file:
                f.write(lines_file.read())
