import argparse
import os

# Parse command line arguments
parser = argparse.ArgumentParser(description='LSTM model for price prediction')
parser.add_argument('--epochs', type=int, help='Number of epochs (default depends on dataset size)')
parser.add_argument('--batch_size', type=int, help='Batch size (default depends on dataset size)')
parser.add_argument('--csv_file', type=str, required=True, help='Path to the CSV file')
parser.add_argument('--latest_date', type=str, help='last date for csv output')
#parser.add_argument('--usecols', type=int, nargs='+', default=[4, 5], help='Columns/Features to use from the CSV file (default 4 5; For a data set with 1500 rows, around 5-20 well-chosen features are often ideal)')
parser.add_argument('--usecols', type=int, nargs='+', default=None, help='Columns/Features to use from the CSV file (default: use all columns)')
parser.add_argument('--predictions', type=int, default=1, help='Number of predictions (default 1)')
parser.add_argument('--look_back', type=int, help='Number of look_back (default depends on dataset size)')
parser.add_argument('--train_ratio', type=float, help='Train ratio (default depends on dataset size)')
parser.add_argument('--verbose', type=int, default=0, help='be verbose (default 0)')
parser.add_argument('--show_rmse', action='store_true', help='Show RMSE scores')
parser.add_argument('--csv_output', action='store_true', help='print results and parameters in CSV format')
parser.add_argument('--patience', type=int, help='Patience for early stopping (default depends on dataset size)')
parser.add_argument('--lstm_units', type=int, help='Number of LSTM units (default depends on dataset size)')
parser.add_argument('--dropout_rate', type=float, help='Dropout rate (default depends on dataset size)')
parser.add_argument('--dense_units', type=int, help='Number of units in the Dense layer (default depends on dataset size)')
args = parser.parse_args()

# Check if the CSV file exists
if not os.path.isfile(args.csv_file):
    raise FileNotFoundError(f"The CSV file '{args.csv_file}' does not exist.")

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

import absl.logging
absl.logging.set_verbosity(absl.logging.FATAL)
import numpy as np
import pandas as pd
from pandas import read_csv
from sklearn.preprocessing import MinMaxScaler
from sklearn.metrics import mean_squared_error
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.callbacks import EarlyStopping
from tensorflow.keras.layers import Dense, LSTM, Input, Dropout

# Function to create dataset with multiple features
def create_dataset_multivariate(dataset, look_back=1):
    dataX, dataY = [], []
    for i in range(len(dataset) - look_back - 1):
        a = dataset[i:(i + look_back), :]  # All features for the look-back period
        dataX.append(a)
        dataY.append(dataset[i + look_back, 0])  # Target value remains the first column (e.g., price)
    return np.array(dataX), np.array(dataY)

# Function to automatical choose often ideal values based on number of rows
def adjust_parameters(num_rows, num_features, epochs=None, batch_size=None, train_ratio=None, look_back=None, patience=None, lstm_units=None, dropout_rate=None, dense_units=None):

    # Multiply num_rows by num_features
    total_data_points = num_rows * num_features

    if total_data_points < 1000:
        default_values = (20, 16, 0.8, 2, 15, 32, 0.2, 16)
    elif total_data_points < 5000:
        default_values = (75, 32, 0.75, 3, 20, 64, 0.3, 32)
    elif total_data_points < 10000:
        default_values = (100, 64, 0.7, 5, 25, 128, 0.3, 64)
    else:
        default_values = (200, 64, 0.67, 7, 30, 256, 0.4, 128)
    
    return (epochs or default_values[0],
            batch_size or default_values[1],
            train_ratio or default_values[2],
            look_back or default_values[3],
            patience or default_values[4],
            lstm_units or default_values[5],
            dropout_rate or default_values[6],
            dense_units or default_values[7])


# Load CSV file and select specified columns
#dataframe = read_csv(args.csv_file, usecols=args.usecols, engine='python')
dataframe = pd.read_csv(args.csv_file, engine='python')

# If usecols is not specified, use all columns
if args.usecols is None:
    args.usecols = list(range(len(dataframe.columns)))
# Select specified columns
dataframe = dataframe.iloc[:, args.usecols]

# Convert all columns to numeric, handling any non-numeric data
dataframe = dataframe.apply(pd.to_numeric, errors='coerce')

# how to handle empty values
dataframe = dataframe.interpolate() # interpolate value
#dataframe = dataframe.fillna(0)  # fill with 0
dataframe = dataframe.fillna(dataframe.mean())  # fill with avarage value
dataframe = dataframe.ffill()  # fill with last known value
#dataframe = dataframe.dropna() # drop whole row

# convert to float32
dataset = dataframe.values.astype('float32')

num_rows = len(dataset)
num_features = len(args.usecols)
epochs, batch_size, train_ratio, look_back, patience, lstm_units, dropout_rate, dense_units = adjust_parameters(
    num_rows,
    num_features,
    args.epochs,
    args.batch_size,
    args.train_ratio,
    args.look_back,
    args.patience,
    args.lstm_units,
    args.dropout_rate,
    args.dense_units
)

# Set random seed for reproducibility
tf.random.set_seed(42)

# Normalize the data (all columns)
scaler = MinMaxScaler(feature_range=(0, 1))
dataset = scaler.fit_transform(dataset)

# Split into train and test sets
train_size = int(len(dataset) * train_ratio)
test_size = len(dataset) - train_size
train, test = dataset[0:train_size, :], dataset[train_size:len(dataset), :]

# Define look-back value
look_back = look_back

# Create datasets with multiple features
trainX, trainY = create_dataset_multivariate(train, look_back)
testX, testY = create_dataset_multivariate(test, look_back)

# Reshape input for LSTM: [Samples, Time Steps, Features]
trainX = np.reshape(trainX, (trainX.shape[0], trainX.shape[1], trainX.shape[2]))
testX = np.reshape(testX, (testX.shape[0], testX.shape[1], testX.shape[2]))

# Create LSTM model
#model = Sequential()
#model.add(LSTM(50, input_shape=(look_back, trainX.shape[2])))  # Look-back and number of features
#model.add(Dense(1))  # Output is a single value (e.g., price)
#model.compile(loss='mean_squared_error', optimizer='adam')
model = Sequential([
    Input(shape=(look_back, trainX.shape[2])),
    LSTM(lstm_units),
    Dropout(dropout_rate), # 20% of the neurons are randomly deactivated to prevent overfitting
    Dense(dense_units),
    Dense(1)
])
model.compile(loss='mean_squared_error', optimizer='adam')

# Train the model
early_stopping = EarlyStopping(monitor='val_loss', patience=patience, restore_best_weights=True)
model.fit(trainX, trainY,
          epochs=epochs,
          batch_size=batch_size,
          validation_data=(testX, testY),
          callbacks=[early_stopping],
          verbose=args.verbose)
#model.fit(trainX, trainY,
#          epochs=epochs,
#          batch_size=batch_size,
#          verbose=args.verbose)

# Make predictions
trainPredict = model.predict(trainX, verbose=args.verbose)
testPredict = model.predict(testX, verbose=args.verbose)

# Invert predictions (restore to original value range)
trainPredict = scaler.inverse_transform(np.concatenate((trainPredict, np.zeros((trainPredict.shape[0], dataset.shape[1] - 1))), axis=1))[:, 0]
trainY = scaler.inverse_transform(np.concatenate((trainY.reshape(-1, 1), np.zeros((trainY.shape[0], dataset.shape[1] - 1))), axis=1))[:, 0]
testPredict = scaler.inverse_transform(np.concatenate((testPredict, np.zeros((testPredict.shape[0], dataset.shape[1] - 1))), axis=1))[:, 0]
testY = scaler.inverse_transform(np.concatenate((testY.reshape(-1, 1), np.zeros((testY.shape[0], dataset.shape[1] - 1))), axis=1))[:, 0]

# Calculate and optionally display RMSE
trainScore = np.sqrt(mean_squared_error(trainY, trainPredict))
testScore = np.sqrt(mean_squared_error(testY, testPredict))
if args.show_rmse:
    print(f'RMSE_TRAIN_SCORE={trainScore:.9f}')
    print(f'RMSE_TEST_SCORE={testScore:.9f}')

# Predictions for the next 7 time points
last_data = dataset[-look_back:]  # Last known data points
future_predictions = []

for _ in range(args.predictions):
    X = last_data[-look_back:].reshape((1, look_back, dataset.shape[1]))
    prediction = model.predict(X, verbose=args.verbose)
    new_data_point = np.zeros((1, dataset.shape[1]))
    new_data_point[0, 0] = prediction[0, 0]  # Set only the first value (e.g., price)
    last_data = np.vstack((last_data, new_data_point))
    future_predictions.append(prediction[0, 0])

# Invert scaling for future predictions
future_predictions = scaler.inverse_transform(np.concatenate((np.array(future_predictions).reshape(-1, 1), np.zeros((len(future_predictions), dataset.shape[1] - 1))), axis=1))[:, 0]

# Output predictions
#print("\nPredictions for the next 7 time points:")
for i, pred in enumerate(future_predictions, 1):
    #print(f'PREDICTION={pred:.9f}')
    if args.csv_output:
      print(f'{args.latest_date},{pred:.9f},{trainScore:.9f},{testScore:.9f},{epochs},{batch_size},{train_ratio},{look_back},{patience},{lstm_units},{dropout_rate},{dense_units}')
    else:
      print(f'PREDICTION={pred:.9f}')
